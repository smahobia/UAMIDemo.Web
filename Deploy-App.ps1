<#
.SYNOPSIS
    Deploys the UAMIDemo.Web application to Azure App Service.
.DESCRIPTION
    This script:
    1. Builds and publishes the .NET application locally.
    2. Zips the published artifacts.
    3. Creates an App Service Plan (Linux) if it doesn't exist.
    4. Creates a Web App if it doesn't exist.
    5. Configures the Web App to use the User-Assigned Managed Identity.
    6. Sets environment variables for Key Vault and UAMI.
    7. Deploys the zip file to the Web App.
.EXAMPLE
    .\Deploy-App.ps1 -SubscriptionId "your-sub-id" -ResourceGroupName "rg-uami-demo" -AppName "uami-demo-app"
#>

param(
    [Parameter(Mandatory = $true, HelpMessage = "Azure Subscription ID")]
    [string]$SubscriptionId,

    [Parameter(Mandatory = $true, HelpMessage = "Azure Resource Group name")]
    [string]$ResourceGroupName,

    [Parameter(Mandatory = $true, HelpMessage = "Unique name for the App Service")]
    [string]$AppName,

    [Parameter(Mandatory = $false, HelpMessage = "Azure region (default: eastus)")]
    [string]$Location = "eastus",
    
    [Parameter(Mandatory = $false, HelpMessage = "SKU for App Service Plan (default: B1)")]
    [string]$Sku = "B1"
)

$ErrorActionPreference = "Stop"

function Write-Success { param([string]$Message) Write-Host "✓ $Message" -ForegroundColor Green }
function Write-Info { param([string]$Message) Write-Host "ℹ $Message" -ForegroundColor Cyan }
function Write-Error-Custom { param([string]$Message) Write-Host "✗ $Message" -ForegroundColor Red }

# Check for configuration file from Create-AzureResources.ps1
$configFile = "azure-resources-config.json"
$config = $null
if (Test-Path $configFile) {
    Write-Info "Found configuration file: $configFile"
    $config = Get-Content $configFile | ConvertFrom-Json
} else {
    Write-Warning "Configuration file '$configFile' not found. Ensure you have run 'Create-AzureResources.ps1' or resources exist."
}

# Connect to Azure
Write-Info "Connecting to Azure..."
Connect-AzAccount -SubscriptionId $SubscriptionId | Out-Null
Set-AzContext -SubscriptionId $SubscriptionId | Out-Null

# Build and Publish Local
$publishDir = ".\bin\Release\net10.0\publish"
$zipPath = ".\uami-demo.zip"

Write-Info "Building and publishing application..."
dotnet publish -c Release -o $publishDir
if ($LASTEXITCODE -ne 0) { throw "Build failed" }

Write-Info "Zipping published files..."
if (Test-Path $zipPath) { Remove-Item $zipPath }
Compress-Archive -Path "$publishDir\*" -DestinationPath $zipPath -Force

# Create App Service Plan
$planName = "$AppName-plan"
Write-Info "Creating App Service Plan '$planName' (Linux/$Sku)..."
$plan = Get-AzAppServicePlan -ResourceGroupName $ResourceGroupName -Name $planName -ErrorAction SilentlyContinue
if (-not $plan) {
    $plan = New-AzAppServicePlan -ResourceGroupName $ResourceGroupName -Name $planName -Location $Location -Tier Basic -WorkerSize Small -Linux
    Write-Success "Created App Service Plan"
} else {
    Write-Success "Using existing App Service Plan"
}

# Create Web App
Write-Info "Creating Web App '$AppName'..."
$webApp = Get-AzWebApp -ResourceGroupName $ResourceGroupName -Name $AppName -ErrorAction SilentlyContinue
if (-not $webApp) {
    # Note: Using DOTNET|10.0 if available, otherwise fallback or update after creation
    # Usually the format is "DOTNETCORE|X.X" or "DOTNET|X.X"
    $props = @{
        "linuxFxVersion" = "DOTNETCORE|10.0"
    }
    $webApp = New-AzWebApp -ResourceGroupName $ResourceGroupName -Name $AppName -AppServicePlan $planName -Location $Location
    # Configure stack separately ensuring it's set correctly
    Set-AzWebApp -ResourceGroupName $ResourceGroupName -Name $AppName -Linux -ContainerImageName "DOTNETCORE|10.0" | Out-Null
    Write-Success "Created Web App"
} else {
    Write-Success "Using existing Web App"
}

# Configure Managed Identity
$uamiId = $null
$uamiClientId = $null
$kvUrl = $null

if ($config) {
    # Use first UAMI and KV from config
    $uamiId = $config.uamis[0].resourceId
    $uamiClientId = $config.uamis[0].clientId
    $kvUrl = $config.keyVaults[0].uri
} else {
    # Fallback to finding by convention or existing
    Write-Info "Searching for UAMI in resource group..."
    $uamis = Get-AzUserAssignedIdentity -ResourceGroupName $ResourceGroupName
    if ($uamis.Count -gt 0) {
        $uamiId = $uamis[0].Id
        $uamiClientId = $uamis[0].ClientId
    }
    
    Write-Info "Searching for Key Vault in resource group..."
    $kvs = Get-AzKeyVault -ResourceGroupName $ResourceGroupName
    if ($kvs.Count -gt 0) {
        $kvUrl = $kvs[0].VaultUri
    }
}

if ($uamiId) {
    Write-Info "Assigning User-Assigned Managed Identity to Web App..."
    $identities = @($uamiId)
    # Update identity to UserAssigned
    Update-AzWebApp -ResourceGroupName $ResourceGroupName -Name $AppName -IdentityType UserAssigned -IdentityId $identities
    Write-Success "Identity assigned"
} else {
    Write-Warning "No User-Assigned Managed Identity found. Skipping identity assignment."
}

# Configure App Settings
$appSettings = @{
    "Azure__UseDefaultCredential" = "true"
}

if ($kvUrl) { $appSettings["Azure__KeyVaultUrl"] = $kvUrl }
if ($uamiClientId) { $appSettings["Azure__ExpectedUamiClientId"] = $uamiClientId }

# Add ASPNETCORE_ENVIRONMENT
$appSettings["ASPNETCORE_ENVIRONMENT"] = "Production"

Write-Info "Updating App Settings..."
Set-AzWebApp -ResourceGroupName $ResourceGroupName -Name $AppName -AppSettings $appSettings | Out-Null
Write-Success "App Settings updated"

# Deploy Code
Write-Info "Deploying application code..."
Publish-AzWebApp -ResourceGroupName $ResourceGroupName -Name $AppName -ArchivePath $zipPath -Force
Write-Success "Deployment complete!"

# Clean up zip
Remove-Item $zipPath -ErrorAction SilentlyContinue

Write-Info ""
Write-Success "App is running at: https://$($webApp.DefaultHostName)"
