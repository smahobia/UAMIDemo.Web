<#
.SYNOPSIS
    Deletes User-Assigned Managed Identities and Key Vaults created for UAMIDemo.Web
.DESCRIPTION
    This script removes all Azure resources created by Create-AzureResources.ps1:
    - 2 User-Assigned Managed Identities (UAMIs)
    - 2 Key Vaults and all their secrets
.EXAMPLE
    .\Delete-AzureResources.ps1 -SubscriptionId "your-sub-id" -ResourceGroupName "rg-uami-demo"

    # Or use the saved config file:
    .\Delete-AzureResources.ps1 -ConfigFile "azure-resources-config.json"
#>

param(
    [Parameter(Mandatory = $false, HelpMessage = "Azure Subscription ID")]
    [string]$SubscriptionId,

    [Parameter(Mandatory = $false, HelpMessage = "Azure Resource Group name")]
    [string]$ResourceGroupName,

    [Parameter(Mandatory = $false, HelpMessage = "Path to config file from Create script")]
    [string]$ConfigFile,

    [Parameter(Mandatory = $false, HelpMessage = "Skip confirmation prompt")]
    [switch]$Force
)

# Set up error handling
$ErrorActionPreference = "Stop"

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

try {
    # Load config from file or parameters
    if ($ConfigFile) {
        if (-not (Test-Path $ConfigFile)) {
            Write-Error-Custom "Config file not found: $ConfigFile"
            exit 1
        }
        Write-Info "Loading configuration from: $ConfigFile"
        $config = Get-Content -Path $ConfigFile | ConvertFrom-Json
        $SubscriptionId = $config.subscriptionId
        $ResourceGroupName = $config.resourceGroupName
    } else {
        if (-not $SubscriptionId -or -not $ResourceGroupName) {
            Write-Error-Custom "Either -ConfigFile or both -SubscriptionId and -ResourceGroupName must be provided"
            exit 1
        }
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

    # Verify resource group exists
    Write-Info "Verifying resource group: $ResourceGroupName..."
    $rg = Get-AzResourceGroup -Name $ResourceGroupName -ErrorAction SilentlyContinue
    if (-not $rg) {
        Write-Error-Custom "Resource group '$ResourceGroupName' not found"
        exit 1
    }
    Write-Success "Resource group found"

    # Get resources to delete
    Write-Info "Finding resources to delete..."
    $uamis = Get-AzUserAssignedIdentity -ResourceGroupName $ResourceGroupName -ErrorAction SilentlyContinue
    $kvs = Get-AzKeyVault -ResourceGroupName $ResourceGroupName -ErrorAction SilentlyContinue

    if (-not $uamis -and -not $kvs) {
        Write-Warning-Custom "No UAMIs or Key Vaults found in resource group '$ResourceGroupName'"
        exit 0
    }

    # Display what will be deleted
    Write-Info ""
    Write-Info "============ Resources to be DELETED ============"
    if ($uamis) {
        Write-Host ""
        Write-Host "User-Assigned Managed Identities:" -ForegroundColor Yellow
        foreach ($uami in $uamis) {
            Write-Host "  - $($uami.Name) (Client ID: $($uami.ClientId))"
        }
    }

    if ($kvs) {
        Write-Host ""
        Write-Host "Key Vaults:" -ForegroundColor Yellow
        foreach ($kv in $kvs) {
            Write-Host "  - $($kv.VaultName)"
            # Count secrets
            $secrets = Get-AzKeyVaultSecret -VaultName $kv.VaultName -ErrorAction SilentlyContinue
            if ($secrets) {
                $secretCount = @($secrets).Count
                Write-Host "      └─ $secretCount secret(s)"
            }
        }
    }

    # Confirmation
    Write-Host ""
    if (-not $Force) {
        Write-Warning-Custom "THIS ACTION CANNOT BE UNDONE!"
        $response = Read-Host "Are you sure you want to delete these resources? Type 'yes' to confirm"
        if ($response -ne "yes") {
            Write-Info "Deletion cancelled"
            exit 0
        }
    }

    # Delete Key Vaults first (they protect user data)
    if ($kvs) {
        Write-Info ""
        Write-Info "============ Deleting Key Vaults ============"
        foreach ($kv in $kvs) {
            Write-Info "Deleting Key Vault: $($kv.VaultName)..."

            # Delete all secrets first
            $secrets = Get-AzKeyVaultSecret -VaultName $kv.VaultName -ErrorAction SilentlyContinue
            if ($secrets) {
                foreach ($secret in $secrets) {
                    Write-Info "  Removing secret: $($secret.Name)..."
                    Remove-AzKeyVaultSecret -VaultName $kv.VaultName -Name $secret.Name -Force -ErrorAction SilentlyContinue | Out-Null
                }
            }

            # Delete the vault
            Remove-AzKeyVault -VaultName $kv.VaultName -ResourceGroupName $ResourceGroupName -Force -ErrorAction SilentlyContinue | Out-Null
            Write-Success "Deleted Key Vault: $($kv.VaultName)"
        }
    }

    # Delete UAMIs
    if ($uamis) {
        Write-Info ""
        Write-Info "============ Deleting User-Assigned Managed Identities ============"
        foreach ($uami in $uamis) {
            Write-Info "Deleting UAMI: $($uami.Name)..."
            Remove-AzUserAssignedIdentity -ResourceGroupName $ResourceGroupName -Name $uami.Name -Force -ErrorAction SilentlyContinue | Out-Null
            Write-Success "Deleted UAMI: $($uami.Name)"
        }
    }

    Write-Host ""
    Write-Success "All resources deleted successfully!"
    Write-Info "Resource group '$ResourceGroupName' remains for other resources"

} catch {
    Write-Error-Custom "An error occurred: $_"
    exit 1
}
