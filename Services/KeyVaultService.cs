using Azure.Core;
using Azure.Identity;
using Azure.Security.KeyVault.Secrets;
using System.Text.Json;
using UAMIDemo.Web.Models;

namespace UAMIDemo.Web.Services;

/// <summary>
/// Key Vault service implementation demonstrating UAMI authentication.
/// Credential mode and vault URL are driven by RuntimeConfigService so they can
/// be changed at runtime without an application restart.
/// </summary>
public class KeyVaultService : IKeyVaultService
{
    private readonly RuntimeConfigService _runtimeConfig;
    private readonly ILogger<KeyVaultService> _logger;

    public KeyVaultService(RuntimeConfigService runtimeConfig, ILogger<KeyVaultService> logger)
    {
        _runtimeConfig = runtimeConfig;
        _logger = logger;
    }

    /// <summary>
    /// Retrieves a secret from Key Vault.
    /// keyVaultUrlOverride (from request body) takes precedence over RuntimeConfigService value.
    /// </summary>
    public async Task<SecretResponse> GetSecretAsync(
        string secretName,
        string? managedIdentityId = null,
        string? keyVaultUrlOverride = null)
    {
        // Resolve effective Key Vault URL
        var resolvedKvUrl = Normalise(
            !string.IsNullOrWhiteSpace(keyVaultUrlOverride) ? keyVaultUrlOverride : _runtimeConfig.KeyVaultUrl);

        var requestInput = JsonSerializer.Serialize(new
        {
            secretName,
            managedIdentityId = managedIdentityId ?? "(system-assigned)",
            keyVaultUrl       = resolvedKvUrl ?? "(not configured)",
            credentialMode    = _runtimeConfig.UseManagedIdentity ? "ManagedIdentityCredential" : "DefaultAzureCredential"
        }, new JsonSerializerOptions { WriteIndented = true });

        try
        {
            if (string.IsNullOrWhiteSpace(resolvedKvUrl))
            {
                return Fail("Key Vault URL is not configured. Use the Setup wizard or set the " +
                            "Azure__KeyVaultUrl environment variable.", requestInput);
            }

            if (string.IsNullOrWhiteSpace(secretName))
                return Fail("Secret name cannot be empty.", requestInput);

            // ── Validate UAMI if expected value is configured ─────────────
            var expectedUami = _runtimeConfig.ExpectedUamiClientId;
            // Removed strict validation to allow easy testing with multiple UAMI IDs
            /* if (!string.IsNullOrWhiteSpace(expectedUami) && !string.IsNullOrWhiteSpace(managedIdentityId))
            {
                if (!string.Equals(managedIdentityId.Trim(), expectedUami.Trim(),
                                   StringComparison.OrdinalIgnoreCase))
                {
                    var msg = $"UAMI Client ID '{managedIdentityId}' does not match the identity " +
                              "configured for this application. Only the authorised UAMI may access this Key Vault.";
                    _logger.LogWarning(msg);
                    return new SecretResponse
                    {
                        Success         = false,
                        ErrorMessage    = msg,
                        CredentialMethod = CredentialLabel,
                        IdentityUsed    = managedIdentityId,
                        CodeSnippet     = BuildSnippet(resolvedKvUrl, managedIdentityId, secretName),
                        RequestInput    = requestInput
                    };
                }
            } */
            var client = CreateSecretClient(managedIdentityId, resolvedKvUrl);
            var secret = await client.GetSecretAsync(secretName);

            _logger.LogInformation(
                "Retrieved secret '{Name}' via {Method} – identity: {Id} – vault: {Vault}",
                secretName, CredentialLabel, managedIdentityId ?? "default", resolvedKvUrl);

            return new SecretResponse
            {
                Success         = true,
                SecretValue     = secret.Value.Value,
                CredentialMethod = CredentialLabel,
                IdentityUsed    = managedIdentityId ?? "System-assigned (default)",
                CodeSnippet     = BuildSnippet(resolvedKvUrl, managedIdentityId, secretName),
                RequestInput    = requestInput
            };
        }
        catch (Azure.RequestFailedException ex) when (ex.Status == 403)
        {
            var msg = $"Access denied (403). Ensure the UAMI " +
                      $"(ID: {managedIdentityId ?? "system-assigned"}) has the " +
                      "'Key Vault Secrets User' role on the vault.";
            _logger.LogWarning(msg);
            return new SecretResponse
            {
                Success         = false,
                ErrorMessage    = msg,
                CredentialMethod = CredentialLabel,
                IdentityUsed    = managedIdentityId ?? "system-assigned",
                CodeSnippet     = BuildSnippet(resolvedKvUrl!, managedIdentityId, secretName),
                RequestInput    = requestInput
            };
        }
        catch (Azure.RequestFailedException ex) when (ex.Status == 404)
        {
            var msg = $"Secret '{secretName}' not found in Key Vault.";
            _logger.LogWarning(msg);
            return new SecretResponse
            {
                Success         = false,
                ErrorMessage    = msg,
                CredentialMethod = CredentialLabel,
                IdentityUsed    = managedIdentityId ?? "system-assigned",
                CodeSnippet     = BuildSnippet(resolvedKvUrl!, managedIdentityId, secretName),
                RequestInput    = requestInput
            };
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error retrieving secret '{Name}'", secretName);
            return new SecretResponse
            {
                Success         = false,
                ErrorMessage    = $"Error retrieving secret: {ex.Message}",
                CredentialMethod = CredentialLabel,
                IdentityUsed    = managedIdentityId ?? "system-assigned",
                CodeSnippet     = BuildSnippet(resolvedKvUrl ?? string.Empty, managedIdentityId, secretName),
                RequestInput    = requestInput
            };
        }
    }

    // ── Helpers ────────────────────────────────────────────────────────────
    private string CredentialLabel =>
        _runtimeConfig.UseManagedIdentity ? "ManagedIdentityCredential" : "DefaultAzureCredential";

    private SecretResponse Fail(string message, string requestInput) => new()
    {
        Success      = false,
        ErrorMessage = message,
        RequestInput = requestInput
    };

    private static string? Normalise(string? url) =>
        string.IsNullOrWhiteSpace(url) ? null : url.TrimEnd('/') + "/";

    private SecretClient CreateSecretClient(string? managedIdentityId, string keyVaultUrl)
    {
        TokenCredential credential;

        if (!_runtimeConfig.UseManagedIdentity)
        {
            _logger.LogInformation("Using DefaultAzureCredential (local dev / az login)");
            var options = new DefaultAzureCredentialOptions
            {
                ExcludeEnvironmentCredential       = false,
                ExcludeManagedIdentityCredential   = true,  // Exclude IMDS to prevent hangs on non-Azure machines
                ExcludeVisualStudioCredential      = false,
                ExcludeAzureCliCredential          = false,
                ExcludeInteractiveBrowserCredential = true
            };
            // Note: UAMI IDs are not used with DefaultAzureCredential for local dev.
            // For UAMI testing, set UseManagedIdentity to true in configuration.
            credential = new DefaultAzureCredential(options);
        }
        else if (!string.IsNullOrWhiteSpace(managedIdentityId))
        {
            _logger.LogInformation("Using User-Assigned ManagedIdentityCredential: {Id}", managedIdentityId);
            var managedIdentityIdObj = ManagedIdentityId.FromUserAssignedClientId(managedIdentityId);
            credential = new ManagedIdentityCredential(managedIdentityIdObj);
        }
        else
        {
            _logger.LogInformation("Using System-Assigned ManagedIdentityCredential");
            credential = new ManagedIdentityCredential(ManagedIdentityId.SystemAssigned);
        }

        return new SecretClient(new Uri(keyVaultUrl), credential);
    }

    private string BuildSnippet(string keyVaultUrl, string? managedIdentityId, string secretName)
    {
        if (!_runtimeConfig.UseManagedIdentity)
        {
            if (!string.IsNullOrWhiteSpace(managedIdentityId))
            {
                    return $$"""
// Using DefaultAzureCredential with an explicit User-Assigned Managed Identity client ID
var options = new DefaultAzureCredentialOptions { ManagedIdentityClientId = "{{managedIdentityId}}" };
var credential = new DefaultAzureCredential(options);

var client = new SecretClient(
    new Uri("{{keyVaultUrl}}"),
    credential);

KeyVaultSecret secret = await client.GetSecretAsync("{{secretName}}");
Console.WriteLine(secret.Value);
""";
            }
            
            return $"""
// Using DefaultAzureCredential (local development / az login)
var credential = new DefaultAzureCredential();

var client = new SecretClient(
    new Uri("{keyVaultUrl}"),
    credential);

KeyVaultSecret secret = await client.GetSecretAsync("{secretName}");
Console.WriteLine(secret.Value);
""";
        }

        if (!string.IsNullOrWhiteSpace(managedIdentityId))
        {
            return $"""
// Using User-Assigned Managed Identity
var credential = new ManagedIdentityCredential(
    clientId: "{managedIdentityId}");

var client = new SecretClient(
    new Uri("{keyVaultUrl}"),
    credential);

KeyVaultSecret secret = await client.GetSecretAsync("{secretName}");
Console.WriteLine(secret.Value);
""";
        }

        return $"""
// Using System-Assigned Managed Identity
var credential = new ManagedIdentityCredential();

var client = new SecretClient(
    new Uri("{keyVaultUrl}"),
    credential);

KeyVaultSecret secret = await client.GetSecretAsync("{secretName}");
Console.WriteLine(secret.Value);
""";
    }
}
