using Microsoft.Extensions.Options;

namespace UAMIDemo.Web.Services;

/// <summary>
/// Singleton service holding the active runtime configuration.
/// Values are seeded from appsettings / environment variables on startup,
/// and can be updated live by the discovery wizard without restarting the app.
///
/// SECURITY: No credential values are committed to source – appsettings.json
/// should only hold placeholders (&lt;...&gt;). Real values arrive either through
/// OS environment variables (Azure__KeyVaultUrl, Azure__ExpectedUamiClientId, …)
/// or through the in-app Discovery wizard (stored in-memory only).
/// </summary>
public class RuntimeConfigService
{
    private readonly object _lock = new();

    private string? _keyVaultUrl;
    private string? _expectedUamiClientId;
    private string? _tenantId;
    private bool _useManagedIdentity;

    public RuntimeConfigService(IOptions<AzureSettings> baseSettings)
    {
        var s = baseSettings.Value;
        _useManagedIdentity = !s.UseDefaultCredential;
        _keyVaultUrl          = IsReal(s.KeyVaultUrl)          ? s.KeyVaultUrl          : null;
        _expectedUamiClientId = IsReal(s.ExpectedUamiClientId) ? s.ExpectedUamiClientId : null;
        _tenantId             = IsReal(s.TenantId)             ? s.TenantId             : null;
    }

    // ── Read properties (thread-safe) ────────────────────────────────────
    public string? KeyVaultUrl          { get { lock (_lock) return _keyVaultUrl;          } }
    public string? ExpectedUamiClientId { get { lock (_lock) return _expectedUamiClientId; } }
    public string? TenantId             { get { lock (_lock) return _tenantId;             } }
    public bool    UseManagedIdentity   { get { lock (_lock) return _useManagedIdentity;   } }

    public bool IsConfigured =>
        !string.IsNullOrWhiteSpace(KeyVaultUrl) &&
        !string.IsNullOrWhiteSpace(ExpectedUamiClientId);

    // ── Mutation helpers (thread-safe) ────────────────────────────────────
    public void SetCredentialMode(bool useManagedIdentity)
    {
        lock (_lock) _useManagedIdentity = useManagedIdentity;
    }

    public void Apply(string? keyVaultUrl, string? uamiClientId, string? tenantId, bool? useManagedIdentity)
    {
        lock (_lock)
        {
            if (!string.IsNullOrWhiteSpace(keyVaultUrl))  _keyVaultUrl          = keyVaultUrl;
            if (!string.IsNullOrWhiteSpace(uamiClientId)) _expectedUamiClientId = uamiClientId;
            if (!string.IsNullOrWhiteSpace(tenantId))     _tenantId             = tenantId;
            if (useManagedIdentity.HasValue)               _useManagedIdentity   = useManagedIdentity.Value;
        }
    }

    public object Snapshot()
    {
        lock (_lock)
        {
            return new
            {
                keyVaultUrl          = _keyVaultUrl          ?? string.Empty,
                expectedUamiClientId = _expectedUamiClientId ?? string.Empty,
                tenantId             = _tenantId             ?? string.Empty,
                useManagedIdentity   = _useManagedIdentity,
                validationEnabled    = !string.IsNullOrWhiteSpace(_expectedUamiClientId),
                isConfigured         = IsConfigured
            };
        }
    }

    // ── Helpers ───────────────────────────────────────────────────────────
    private static bool IsReal(string? v) =>
        !string.IsNullOrWhiteSpace(v) && !v.TrimStart().StartsWith("<");
}
