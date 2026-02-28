# ===================================================================
# Azure UAMI Key Vault Demo - ID Discovery Script
# ===================================================================
# This script helps you discover your Azure subscription, Key Vault,
# and User-Assigned Managed Identity IDs without using `az login`.
#
# Run this in PowerShell, then set the output values as environment
# variables before starting the web app.
# ===================================================================

Write-Host "`n╭─ Azure ID Discovery Script ─────────────────────────────────`n" -ForegroundColor Cyan

# Check if Az.Accounts module is available
if (-not (Get-Module -Name Az.Accounts -ListAvailable)) {
    Write-Host "❌ Azure PowerShell module not found." -ForegroundColor Red
    Write-Host "`nTo install, run:" -ForegroundColor Yellow
    Write-Host "  Install-Module -Name Az -Repository PSGallery -Force`n" -ForegroundColor Green
    exit 1
}

# Connect to Azure
Write-Host "🔐 Connecting to Azure..." -ForegroundColor Cyan
$context = Connect-AzAccount -ErrorAction Stop
$account = $context.Context.Account.Id
$tenantId = $context.Context.Tenant.Id

Write-Host "✅ Logged in as: $account`n" -ForegroundColor Green
Write-Host "📌 Tenant ID: $tenantId`n" -ForegroundColor Yellow

# Get subscriptions
Write-Host "📋 Fetching subscriptions..." -ForegroundColor Cyan
$subscriptions = Get-AzSubscription

if ($subscriptions.Count -eq 0) {
    Write-Host "❌ No subscriptions found for this account." -ForegroundColor Red
    Write-Host "`nMake sure your account has access to at least one subscription.`n" -ForegroundColor Yellow
    exit 1
}

Write-Host "✅ Found $($subscriptions.Count) subscription(s):`n" -ForegroundColor Green
$subscriptions | ForEach-Object { Write-Host "   • $($_.Name) [$($_.SubscriptionId)]" }

# Let user select subscription
Write-Host ""
$selectedSub = $subscriptions[0]
if ($subscriptions.Count -gt 1) {
    $index = Read-Host "`nSelect subscription (enter number, default 0)"
    if ($index -match '^\d+$' -and [int]$index -lt $subscriptions.Count) {
        $selectedSub = $subscriptions[[int]$index]
    }
}

$subscriptionId = $selectedSub.SubscriptionId
$subscriptionName = $selectedSub.Name
Write-Host "✅ Selected: $subscriptionName`n" -ForegroundColor Green

# Set context to selected subscription
Set-AzContext -SubscriptionId $subscriptionId | Out-Null

# Get Key Vaults
Write-Host "🔑 Fetching Key Vaults..." -ForegroundColor Cyan
$keyVaults = Get-AzKeyVault

if ($keyVaults.Count -eq 0) {
    Write-Host "⚠️  No Key Vaults found in this subscription.`n" -ForegroundColor Yellow
} else {
    Write-Host "✅ Found $($keyVaults.Count) Key Vault(s):`n" -ForegroundColor Green
    $keyVaults | ForEach-Object { 
        Write-Host "   • $($_.VaultName): $($_.VaultUri)"
    }
    
    $selectedKv = $keyVaults[0]
    if ($keyVaults.Count -gt 1) {
        $index = Read-Host "`nSelect Key Vault (enter number, default 0)"
        if ($index -match '^\d+$' -and [int]$index -lt $keyVaults.Count) {
            $selectedKv = $keyVaults[[int]$index]
        }
    }
    $keyVaultUrl = $selectedKv.VaultUri
    Write-Host "`n✅ Selected: $($selectedKv.VaultName) ($keyVaultUrl)`n" -ForegroundColor Green
}

# Get User-Assigned Managed Identities
Write-Host "🪪 Fetching User-Assigned Managed Identities..." -ForegroundColor Cyan
$uamis = Get-AzUserAssignedIdentity

if ($uamis.Count -eq 0) {
    Write-Host "⚠️  No User-Assigned Managed Identities found.`n" -ForegroundColor Yellow
} else {
    Write-Host "✅ Found $($uamis.Count) UAMI(s):`n" -ForegroundColor Green
    $uamis | ForEach-Object { 
        Write-Host "   • $($_.Name) (ClientId: $($_.ClientId))"
    }
    
    $selectedUami = $uamis[0]
    if ($uamis.Count -gt 1) {
        $index = Read-Host "`nSelect UAMI (enter number, default 0)"
        if ($index -match '^\d+$' -and [int]$index -lt $uamis.Count) {
            $selectedUami = $uamis[[int]$index]
        }
    }
    $uamiClientId = $selectedUami.ClientId
    Write-Host "`n✅ Selected: $($selectedUami.Name) (ClientId: $uamiClientId)`n" -ForegroundColor Green
}

# Display results
Write-Host "╭────────────────────────────────────────────────────────────`n" -ForegroundColor Cyan
Write-Host "📋 Your Azure Configuration IDs:`n" -ForegroundColor Cyan

Write-Host "Tenant ID:" -ForegroundColor Yellow
Write-Host "  $tenantId`n"

if ($keyVaultUrl) {
    Write-Host "Key Vault URL:" -ForegroundColor Yellow
    Write-Host "  $keyVaultUrl`n"
}

if ($uamiClientId) {
    Write-Host "UAMI Client ID:" -ForegroundColor Yellow
    Write-Host "  $uamiClientId`n"
}

# Generate environment variable commands
Write-Host "╭────────────────────────────────────────────────────────────`n" -ForegroundColor Cyan
Write-Host "🔧 Set these environment variables before running the app:`n" -ForegroundColor Cyan

Write-Host "# PowerShell (copy & paste into terminal):" -ForegroundColor Green
Write-Host "`$env:Azure__TenantId = '$tenantId'"
if ($keyVaultUrl) { Write-Host "`$env:Azure__KeyVaultUrl = '$keyVaultUrl'" }
if ($uamiClientId) { Write-Host "`$env:Azure__ExpectedUamiClientId = '$uamiClientId'" }
Write-Host ""

Write-Host "# Or set permanently (Windows only):" -ForegroundColor Green
Write-Host "[Environment]::SetEnvironmentVariable('Azure__TenantId', '$tenantId', 'User')"
if ($keyVaultUrl) { Write-Host "[Environment]::SetEnvironmentVariable('Azure__KeyVaultUrl', '$keyVaultUrl', 'User')" }
if ($uamiClientId) { Write-Host "[Environment]::SetEnvironmentVariable('Azure__ExpectedUamiClientId', '$uamiClientId', 'User')" }
Write-Host ""

Write-Host "╰────────────────────────────────────────────────────────────`n" -ForegroundColor Cyan
Write-Host "✅ Ready! Start the web app with 'dotnet run'`n" -ForegroundColor Green
