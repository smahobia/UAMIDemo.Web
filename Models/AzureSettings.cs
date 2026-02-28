namespace UAMIDemo.Web.Services;

/// <summary>
/// Configuration settings for Azure services
/// </summary>
public class AzureSettings
{
    public string KeyVaultUrl { get; set; } = string.Empty;
    public bool UseDefaultCredential { get; set; } = true;
    public string? TenantId { get; set; }
    public string? ClientId { get; set; }
    public string? ClientSecret { get; set; }
    /// <summary>
    /// The Client ID of the expected UAMI. When set, requests using a different UAMI will be rejected.
    /// </summary>
    public string? ExpectedUamiClientId { get; set; }
}
