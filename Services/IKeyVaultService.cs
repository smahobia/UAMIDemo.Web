using UAMIDemo.Web.Models;

namespace UAMIDemo.Web.Services;

/// <summary>
/// Interface for Key Vault operations
/// </summary>
public interface IKeyVaultService
{
    /// <summary>
    /// Retrieves a secret from Key Vault using the specified credential method
    /// </summary>
    Task<SecretResponse> GetSecretAsync(string secretName, string? managedIdentityId = null, string? keyVaultUrlOverride = null);
}
