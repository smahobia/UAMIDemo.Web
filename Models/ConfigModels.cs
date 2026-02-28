namespace UAMIDemo.Web.Models;

/// <summary>
/// Request to toggle the credential mode at runtime (no restart required)
/// </summary>
public class SetCredentialModeRequest
{
    public bool UseManagedIdentity { get; set; }
}

/// <summary>
/// Request to apply discovered/selected config values into in-memory RuntimeConfigService
/// </summary>
public class ApplyConfigRequest
{
    public string? KeyVaultUrl { get; set; }
    public string? ExpectedUamiClientId { get; set; }
    public string? TenantId { get; set; }
    public bool? UseManagedIdentity { get; set; }
}
