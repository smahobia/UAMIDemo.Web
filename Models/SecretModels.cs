namespace UAMIDemo.Web.Models;

/// <summary>
/// Request/Response model for Key Vault secret retrieval
/// </summary>
public class SecretRequest
{
    public string? SecretName { get; set; }
    public string? ManagedIdentityId { get; set; }
    /// <summary>
    /// Key Vault URL to retrieve from. Overrides appsettings KeyVaultUrl when provided.
    /// </summary>
    public string? KeyVaultUrl { get; set; }
}

/// <summary>
/// Response model for secret retrieval results
/// </summary>
public class SecretResponse
{
    public bool Success { get; set; }
    public string? SecretValue { get; set; }
    public string? ErrorMessage { get; set; }
    public string? CredentialMethod { get; set; }
    public string? IdentityUsed { get; set; }
    /// <summary>
    /// The C# code snippet that was executed to retrieve the secret
    /// </summary>
    public string? CodeSnippet { get; set; }
    /// <summary>
    /// Serialised form of the request inputs used
    /// </summary>
    public string? RequestInput { get; set; }
}
