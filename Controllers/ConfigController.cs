using Azure.Core;
using Azure.Identity;
using Azure.ResourceManager;
using Azure.ResourceManager.KeyVault;
using Azure.ResourceManager.ManagedServiceIdentities;
using Microsoft.AspNetCore.Mvc;
using System.Text.Json;
using System.Threading.Channels;
using UAMIDemo.Web.Models;
using UAMIDemo.Web.Services;

namespace UAMIDemo.Web.Controllers;

/// <summary>
/// Manages runtime configuration:
///   GET  /api/config/current         – returns active in-memory config snapshot
///   POST /api/config/credential-mode – toggle DefaultAzure ↔ ManagedIdentity
///   POST /api/config/apply           – apply discovered values into RuntimeConfigService
///   GET  /api/config/discover        – SSE stream: device-code login → enumerate UAMIs + KVs
/// </summary>
[ApiController]
[Route("api/[controller]")]
public class ConfigController : ControllerBase
{
    private readonly RuntimeConfigService _runtimeConfig;
    private readonly ILogger<ConfigController> _logger;

    public ConfigController(RuntimeConfigService runtimeConfig, ILogger<ConfigController> logger)
    {
        _runtimeConfig = runtimeConfig;
        _logger = logger;
    }

    // ── GET /api/config/current ──────────────────────────────────────────
    [HttpGet("current")]
    [Produces("application/json")]
    public ActionResult<object> GetCurrent() => Ok(_runtimeConfig.Snapshot());

    // ── POST /api/config/credential-mode ─────────────────────────────────
    [HttpPost("credential-mode")]
    [Produces("application/json")]
    public ActionResult SetCredentialMode([FromBody] SetCredentialModeRequest req)
    {
        _runtimeConfig.SetCredentialMode(req.UseManagedIdentity);
        _logger.LogInformation("Credential mode changed to: {Mode}",
            req.UseManagedIdentity ? "ManagedIdentity" : "DefaultAzureCredential");
        return Ok(new { success = true, useManagedIdentity = req.UseManagedIdentity });
    }

    // ── POST /api/config/apply ───────────────────────────────────────────
    [HttpPost("apply")]
    [Produces("application/json")]
    public ActionResult ApplyConfig([FromBody] ApplyConfigRequest req)
    {
        _runtimeConfig.Apply(req.KeyVaultUrl, req.ExpectedUamiClientId, req.TenantId, req.UseManagedIdentity);
        _logger.LogInformation(
            "Runtime config applied – KV: {KV}, UAMI: {UAMI}, ManagedIdentity: {MI}",
            req.KeyVaultUrl, req.ExpectedUamiClientId, req.UseManagedIdentity);
        return Ok(new { success = true, config = _runtimeConfig.Snapshot() });
    }

    // ── GET /api/config/discover ─────────────────────────────────────────
    /// <summary>
    /// Server-Sent Events stream.
    /// Opens a DeviceCodeCredential (MFA-compatible, no browser popup on server),
    /// emits the device code to the frontend, waits for the user to authenticate,
    /// then enumerates Subscriptions, UAMIs, and Key Vaults.
    ///
    /// Event types:
    ///   device-code   { code, url, message, expiresOn }
    ///   progress      { message }
    ///   subscriptions { data: [...] }
    ///   identities    { data: [...] }
    ///   key-vaults    { data: [...] }
    ///   complete      { tenantId, subscriptionId }
    ///   error         { message }
    /// </summary>
    [HttpGet("discover")]
    public async Task Discover([FromQuery] string? tenantId, CancellationToken ct)
    {
        Response.ContentType  = "text/event-stream";
        Response.Headers["Cache-Control"] = "no-cache";
        Response.Headers["X-Accel-Buffering"] = "no"; // disable nginx buffering

        var channel = Channel.CreateUnbounded<object>(new UnboundedChannelOptions
        {
            SingleReader = true, SingleWriter = false
        });

        async Task Send(object payload)
        {
            try
            {
                var json = JsonSerializer.Serialize(payload, new JsonSerializerOptions
                {
                    PropertyNamingPolicy = JsonNamingPolicy.CamelCase
                });
                await Response.WriteAsync($"data: {json}\n\n", ct);
                await Response.Body.FlushAsync(ct);
            }
            catch { /* client disconnected */ }
        }

        // Start discovery on a background thread so SSE can stream device code
        var discoveryTask = Task.Run(async () =>
        {
            try
            {
                var options = new DefaultAzureCredentialOptions
                {
                    ExcludeInteractiveBrowserCredential = false,
                    ExcludeEnvironmentCredential = false,
                    ExcludeVisualStudioCredential = false,
                    ExcludeAzureCliCredential = false,
                    ExcludeManagedIdentityCredential = true  // Exclude IMDS on non-Azure machines
                };
                if (!string.IsNullOrWhiteSpace(tenantId))
                    options.TenantId = tenantId;

                var credential = new DefaultAzureCredential(options);
                var armClient  = new ArmClient(credential);

                await channel.Writer.WriteAsync(new { type = "progress", message = "Authenticating with Azure (checking az login, Visual Studio, or environment credentials)…" });

                var subs = new List<object>();
                string? firstSubId     = null;
                string? detectedTenant = null;

                try
                {
                    await foreach (var sub in armClient.GetSubscriptions().GetAllAsync(ct))
                    {
                        firstSubId     ??= sub.Data.SubscriptionId;
                        detectedTenant ??= sub.Data.TenantId?.ToString();
                        subs.Add(new
                        {
                            id       = sub.Data.SubscriptionId,
                            name     = sub.Data.DisplayName,
                            tenantId = sub.Data.TenantId?.ToString()
                        });
                    }
                }
                catch (Azure.Identity.AuthenticationFailedException authEx)
                {
                    _logger.LogWarning(authEx, "Authentication failed during discovery");
                    await channel.Writer.WriteAsync(new 
                    { 
                        type = "error", 
                        message = "Authentication failed. Make sure you are logged in: run 'az login' in terminal or ensure Visual Studio has cached credentials." 
                    });
                    return;
                }

                if (subs.Count == 0)
                {
                    await channel.Writer.WriteAsync(new { type = "progress", message = "⚠ No subscriptions found. Ensure you are authenticated and have access to at least one subscription." });
                }

                await channel.Writer.WriteAsync(new { type = "subscriptions", data = subs });

                if (firstSubId != null)
                {
                    var subRes = armClient.GetSubscriptionResource(
                        new ResourceIdentifier($"/subscriptions/{firstSubId}"));

                    // ---- Enumerate UAMIs ----
                    await channel.Writer.WriteAsync(new { type = "progress", message = "Enumerating User-Assigned Managed Identities…" });
                    var identities = new List<object>();
                    await foreach (var id in subRes.GetUserAssignedIdentitiesAsync(cancellationToken: ct))
                    {
                        identities.Add(new
                        {
                            name          = id.Data.Name,
                            clientId      = id.Data.ClientId?.ToString(),
                            principalId   = id.Data.PrincipalId?.ToString(),
                            resourceGroup = ExtractRg(id.Data.Id?.ToString())
                        });
                    }
                    await channel.Writer.WriteAsync(new { type = "identities", data = identities });

                    // ---- Enumerate Key Vaults ----
                    await channel.Writer.WriteAsync(new { type = "progress", message = "Enumerating Key Vaults…" });
                    var kvs = new List<object>();
                    await foreach (var kv in subRes.GetKeyVaultsAsync(cancellationToken: ct))
                    {
                        kvs.Add(new
                        {
                            name          = kv.Data.Name,
                            url           = kv.Data.Properties.VaultUri?.ToString() ?? $"https://{kv.Data.Name}.vault.azure.net/",
                            resourceGroup = ExtractRg(kv.Data.Id?.ToString()),
                            location      = kv.Data.Location.ToString()
                        });
                    }
                    await channel.Writer.WriteAsync(new { type = "key-vaults", data = kvs });
                }

                await channel.Writer.WriteAsync(new
                {
                    type           = "complete",
                    tenantId       = detectedTenant ?? tenantId,
                    subscriptionId = firstSubId
                });
            }
            catch (OperationCanceledException) { /* client disconnected */ }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Discovery error");
                await channel.Writer.WriteAsync(new { type = "error", message = ex.Message });
            }
            finally
            {
                channel.Writer.Complete();
            }
        }, ct);

        // Stream channel events to the SSE response
        await foreach (var msg in channel.Reader.ReadAllAsync(ct))
        {
            await Send(msg);
        }

        await discoveryTask;
    }

    private static string? ExtractRg(string? resourceId)
    {
        if (string.IsNullOrEmpty(resourceId)) return null;
        var parts = resourceId.Split('/');
        var idx   = Array.IndexOf(parts, "resourceGroups");
        return idx >= 0 && idx + 1 < parts.Length ? parts[idx + 1] : null;
    }
}
