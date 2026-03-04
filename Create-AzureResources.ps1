<#
.SYNOPSIS
    Creates two User-Assigned Managed Identities and two Key Vaults for UAMIDemo.Web
.DESCRIPTION
    This script automates the creation of Azure resources needed for the UAMIDemo.Web application:
    - 2 User-Assigned Managed Identities (UAMIs)
    - 2 Key Vaults
    - Access permissions between UAMIs and Key Vaults
.EXAMPLE
    .\Create-AzureResources.ps1 -SubscriptionId "your-sub-id" -ResourceGroupName "rg-uami-demo" `
        -Location "eastus" -EnvironmentPrefix "uami-demo"
#>

param(
    [Parameter(Mandatory = $true, HelpMessage = "Azure Subscription ID")]
    [string]$SubscriptionId,

    [Parameter(Mandatory = $true, HelpMessage = "Azure Resource Group name")]
    [string]$ResourceGroupName,

    [Parameter(Mandatory = $true, HelpMessage = "Azure region (e.g., eastus, westus2)")]
    [string]$Location,

    [Parameter(Mandatory = $false, HelpMessage = "Prefix for resource names (default: uami-demo)")]
    [string]$EnvironmentPrefix = "uami-demo",

    [Parameter(Mandatory = $false, HelpMessage = "Enable verbose logging")]
    [switch]$Verbose
)

# Set up error handling
$ErrorActionPreference = "Stop"
$VerbosePreference = if ($Verbose) { "Continue" } else { "SilentlyContinue" }

# Color coded output
function Write-Success {
    param([string]$Message)
    Write-Host "✓ $Message" -ForegroundColor Green
}

function Write-Error-Custom {
    param([string]$Message)
    Write-Host "✗ $Message" -ForegroundColor Red
}

function Write-Info {
    param([string]$Message)
    Write-Host "ℹ $Message" -ForegroundColor Cyan
}

function Write-Warning-Custom {
    param([string]$Message)
    Write-Host "⚠ $Message" -ForegroundColor Yellow
}

# Validate required modules
Write-Info "Checking required Azure PowerShell modules..."
$requiredModules = @("Az.Accounts", "Az.ManagedServiceIdentity", "Az.KeyVault")

foreach ($module in $requiredModules) {
    if (-not (Get-Module -ListAvailable -Name $module)) {
        Write-Error-Custom "Module '$module' not found. Installing..."
        Install-Module -Name $module -Force -AllowClobber -Scope CurrentUser
    }
}

# Import modules
Import-Module Az.Accounts
Import-Module Az.ManagedServiceIdentity
Import-Module Az.KeyVault

try {
    # Connect to Azure
    Write-Info "Connecting to Azure..."
    $context = Get-AzContext
    if (-not $context -or $context.Subscription.Id -ne $SubscriptionId) {
        Connect-AzAccount -SubscriptionId $SubscriptionId | Out-Null
    }
    Write-Success "Connected to Azure"

    # Set subscription context
    Set-AzContext -SubscriptionId $SubscriptionId | Out-Null
    $subscription = Get-AzSubscription -SubscriptionId $SubscriptionId
    Write-Success "Using subscription: $($subscription.Name)"

    # Get or create resource group
    Write-Info "Getting or creating resource group '$ResourceGroupName' in $Location..."
    $rg = Get-AzResourceGroup -Name $ResourceGroupName -ErrorAction SilentlyContinue
    if (-not $rg) {
        $rg = New-AzResourceGroup -Name $ResourceGroupName -Location $Location
        Write-Success "Created resource group: $ResourceGroupName"
    } else {
        Write-Success "Using existing resource group: $ResourceGroupName"
    }

    $tenantId = (Get-AzContext).Tenant.Id
    Write-Info "Tenant ID: $tenantId"

    # Define resource names
    $uamiNames = @(
        "$EnvironmentPrefix-uami-01",
        "$EnvironmentPrefix-uami-02"
    )
    $kvNames = @(
        "$EnvironmentPrefix-kv-01".Replace("-", "").Substring(0, 24),  # KV names have character limits
        "$EnvironmentPrefix-kv-02".Replace("-", "").Substring(0, 24)
    )

    Write-Info "Creating resources with prefix: $EnvironmentPrefix"
    Write-Info "UAMI names: $($uamiNames -join ', ')"
    Write-Info "Key Vault names: $($kvNames -join ', ')"

    # Create UAMIs
    Write-Info ""
    Write-Info "============ Creating User-Assigned Managed Identities ============"
    $uamis = @()

    foreach ($uamiName in $uamiNames) {
        Write-Info "Creating UAMI: $uamiName..."
        $uami = New-AzUserAssignedIdentity `
            -ResourceGroupName $ResourceGroupName `
            -Name $uamiName `
            -Location $Location `
            -ErrorAction SilentlyContinue

        if ($uami) {
            Write-Success "Created UAMI: $uamiName"
            Write-Info "  Client ID: $($uami.ClientId)"
            Write-Info "  Principal ID: $($uami.PrincipalId)"
        } else {
            Write-Warning-Custom "UAMI '$uamiName' may already exist, retrieving..."
            $uami = Get-AzUserAssignedIdentity -ResourceGroupName $ResourceGroupName -Name $uamiName
            Write-Success "Retrieved UAMI: $uamiName"
        }
        $uamis += $uami
    }

    # Create Key Vaults
    Write-Info ""
    Write-Info "============ Creating Key Vaults ============"
    $kvs = @()

    foreach ($i in 0..1) {
        $kvName = $kvNames[$i]
        Write-Info "Creating Key Vault: $kvName..."

        $kv = New-AzKeyVault `
            -ResourceGroupName $ResourceGroupName `
            -VaultName $kvName `
            -Location $Location `
            -EnablePurgeProtection `
            -ErrorAction SilentlyContinue

        if ($kv) {
            Write-Success "Created Key Vault: $kvName"
        } else {
            Write-Warning-Custom "Key Vault '$kvName' may already exist, retrieving..."
            $kv = Get-AzKeyVault -ResourceGroupName $ResourceGroupName -VaultName $kvName
            Write-Success "Retrieved Key Vault: $kvName"
        }
        $kvs += $kv
    }

    # Grant UAMI access to Key Vaults (each UAMI gets access to both KVs)
    Write-Info ""
    Write-Info "============ Setting Access Permissions ============"

    foreach ($i in 0..1) {
        $kvName = $kvs[$i].VaultName
        Write-Info "Granting access to Key Vault: $kvName"

        foreach ($j in 0..1) {
            $uami = $uamis[$j]
            $uamiName = $uamiNames[$j]

            Write-Info "  Granting UAMI '$uamiName' access..."
            Set-AzKeyVaultAccessPolicy `
                -VaultName $kvName `
                -ResourceGroupName $ResourceGroupName `
                -ObjectId $uami.PrincipalId `
                -PermissionsToSecrets Get, List, Set, Delete `
                -ErrorAction SilentlyContinue | Out-Null

            Write-Success "  Granted access for $uamiName"
        }
    }

    # Output configuration
    Write-Info ""
    Write-Info "============ Resource Summary ============"
    Write-Host ""
    Write-Host "User-Assigned Managed Identities:" -ForegroundColor Cyan
    foreach ($uami in $uamis) {
        Write-Host "  Name:       $($uami.Name)"
        Write-Host "  Client ID:  $($uami.ClientId)"
        Write-Host "  Principal:  $($uami.PrincipalId)"
        Write-Host ""
    }

    Write-Host "Key Vaults:" -ForegroundColor Cyan
    foreach ($kv in $kvs) {
        Write-Host "  Name:       $($kv.VaultName)"
        Write-Host "  URI:        $($kv.VaultUri)"
        Write-Host "  Location:   $($kv.Location)"
        Write-Host ""
    }

    # Generate environment variable commands
    Write-Info ""
    Write-Info "============ Environment Variables for Development ============"
    Write-Host ""
    Write-Host "PowerShell (temporary - current session only):" -ForegroundColor Cyan
    Write-Host "`$env:Azure__TenantId = '$tenantId'"
    Write-Host "`$env:Azure__KeyVaultUrl = '$($kvs[0].VaultUri)'"
    Write-Host "`$env:Azure__ExpectedUamiClientId = '$($uamis[0].ClientId)'"
    Write-Host "`$env:Azure__UseDefaultCredential = 'true'"
    Write-Host ""

    Write-Host "PowerShell (permanent - all sessions):" -ForegroundColor Cyan
    Write-Host "[Environment]::SetEnvironmentVariable('Azure__TenantId', '$tenantId', [EnvironmentVariableTarget]::User)"
    Write-Host "[Environment]::SetEnvironmentVariable('Azure__KeyVaultUrl', '$($kvs[0].VaultUri)', [EnvironmentVariableTarget]::User)"
    Write-Host "[Environment]::SetEnvironmentVariable('Azure__ExpectedUamiClientId', '$($uamis[0].ClientId)', [EnvironmentVariableTarget]::User)"
    Write-Host "[Environment]::SetEnvironmentVariable('Azure__UseDefaultCredential', 'true', [EnvironmentVariableTarget]::User)"
    Write-Host ""

    # Save configuration to file
    $configFile = "azure-resources-config.json"
    $config = @{
        timestamp           = (Get-Date -Format "o")
        subscriptionId      = $SubscriptionId
        resourceGroupName   = $ResourceGroupName
        location            = $Location
        tenantId            = $tenantId
        uamis               = $uamis | ForEach-Object {
            @{
                name       = $_.Name
                clientId   = $_.ClientId
                principalId = $_.PrincipalId
                resourceId = $_.Id
            }
        }
        keyVaults           = $kvs | ForEach-Object {
            @{
                name      = $_.VaultName
                uri       = $_.VaultUri
                resourceId = $_.ResourceId
                location  = $_.Location
            }
        }
    }

    $config | ConvertTo-Json | Set-Content -Path $configFile
    Write-Success "Configuration saved to: $configFile"

    Write-Host ""
    Write-Success "All resources created successfully!"

} catch {
    Write-Error-Custom "An error occurred: $_"
    exit 1
}
