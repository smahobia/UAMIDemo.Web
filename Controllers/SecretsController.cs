using Microsoft.AspNetCore.Mvc;
using UAMIDemo.Web.Models;
using UAMIDemo.Web.Services;

namespace UAMIDemo.Web.Controllers;

/// <summary>
/// API controller for Key Vault operations demonstrating UAMI
/// </summary>
[ApiController]
[Route("api/[controller]")]
public class SecretsController : ControllerBase
{
    private readonly IKeyVaultService _keyVaultService;
    private readonly RuntimeConfigService _runtimeConfig;
    private readonly ILogger<SecretsController> _logger;

    public SecretsController(
        IKeyVaultService keyVaultService,
        RuntimeConfigService runtimeConfig,
        ILogger<SecretsController> logger)
    {
        _keyVaultService = keyVaultService;
        _runtimeConfig   = runtimeConfig;
        _logger          = logger;
    }

    /// <summary>
    /// Retrieves a secret from Key Vault
    /// </summary>
    [HttpPost("retrieve")]
    [Produces("application/json")]
    public async Task<ActionResult<SecretResponse>> RetrieveSecret([FromBody] SecretRequest request)
    {
        if (request == null || string.IsNullOrWhiteSpace(request.SecretName))
        {
            return BadRequest(new SecretResponse
            {
                Success = false,
                ErrorMessage = "Secret name is required"
            });
        }

        _logger.LogInformation(
            "Attempting to retrieve secret '{SecretName}' with UAMI: {UAMI}, KeyVault: {KV}",
            request.SecretName,
            request.ManagedIdentityId ?? "system-assigned",
            request.KeyVaultUrl ?? "(from appsettings)");

        var result = await _keyVaultService.GetSecretAsync(
            request.SecretName,
            request.ManagedIdentityId,
            request.KeyVaultUrl);

        return Ok(result);
    }

    /// <summary>
    /// Health check endpoint
    /// </summary>
    [HttpGet("health")]
    public ActionResult<object> Health()
    {
        return Ok(new
        {
            status = "healthy",
            timestamp = DateTime.UtcNow,
            environment = Environment.GetEnvironmentVariable("ASPNETCORE_ENVIRONMENT") ?? "Production"
        });
    }

    /// <summary>
    /// Returns the live runtime configuration snapshot used by the frontend to pre-populate fields.
    /// Delegates to RuntimeConfigService so values updated by the Setup wizard are reflected immediately.
    /// </summary>
    [HttpGet("config")]
    [Produces("application/json")]
    public ActionResult<object> GetConfig() => Ok(_runtimeConfig.Snapshot());
}
