# Azure Resource Management Scripts Guide

## Overview

This guide covers two PowerShell scripts for managing Azure resources for the UAMIDemo.Web application:

- **Create-AzureResources.ps1** - Creates 2 User-Assigned Managed Identities (UAMIs) and 2 Key Vaults
- **Delete-AzureResources.ps1** - Deletes all those resources

## Prerequisites

1. **Azure Subscription** with appropriate permissions (Owner or Contributor role)
2. **Azure PowerShell Module** installed:
   ```powershell
   Install-Module -Name Az -Scope CurrentUser -Force
   ```
3. **Azure CLI** (optional, for `az login` if not already authenticated)

## Quick Start

### Step 1: Create Resources

```powershell
.\Create-AzureResources.ps1 `
    -SubscriptionId "your-subscription-id" `
    -ResourceGroupName "rg-uami-demo" `
    -Location "eastus" `
    -EnvironmentPrefix "uami-demo"
```

**Parameters:**
- `SubscriptionId` (required): Your Azure Subscription ID
- `ResourceGroupName` (required): Name of the resource group to create/use
- `Location` (required): Azure region (e.g., eastus, westus2, canadacentral)
- `EnvironmentPrefix` (optional): Prefix for resource names (default: uami-demo)
- `Verbose` (optional): Enable verbose output with `-Verbose`

**What it creates:**
- 2 UAMIs: `{prefix}-uami-01`, `{prefix}-uami-02`
- 2 Key Vaults: `{prefix}kv01`, `{prefix}kv02`
- Access permissions: Each UAMI can access both Key Vaults

**Output:**
The script generates:
1. **Console Output** - Shows all created resources with Client IDs and URIs
2. **azure-resources-config.json** - Configuration file for later cleanup
3. **Environment Variable Commands** - Ready to copy/paste for your application

### Step 2: Use Environment Variables in Your Application

After creation, the script outputs environment variable commands. Set them:

```powershell
# Temporary (current session only)
$env:Azure__TenantId = 'your-tenant-id'
$env:Azure__KeyVaultUrl = 'https://uamidemokv01.vault.azure.net/'
$env:Azure__ExpectedUamiClientId = 'your-uami-client-id'
$env:Azure__UseDefaultCredential = 'true'

# Or permanent (all sessions - requires admin):
[Environment]::SetEnvironmentVariable('Azure__TenantId', 'your-tenant-id', [EnvironmentVariableTarget]::User)
[Environment]::SetEnvironmentVariable('Azure__KeyVaultUrl', 'https://uamidemokv01.vault.azure.net/', [EnvironmentVariableTarget]::User)
[Environment]::SetEnvironmentVariable('Azure__ExpectedUamiClientId', 'your-uami-client-id', [EnvironmentVariableTarget]::User)
[Environment]::SetEnvironmentVariable('Azure__UseDefaultCredential', 'true', [EnvironmentVariableTarget]::User)
```

Then restart Visual Studio or your terminal session.

### Step 3: Test Your Application

Run UAMIDemo.Web locally:
```powershell
dotnet run --configuration Development
```

Visit: `https://localhost:58067` and use the discovery tool to test UAMI access.

### Step 4: Add Test Secrets to Key Vault

Option A: Using Azure Portal
1. Go to your Key Vault in Azure Portal
2. Click "Secrets" → "Generate/Import"
3. Create a test secret (e.g., `DatabasePassword`, `ApiKey`)

Option B: Using PowerShell
```powershell
$secretValue = ConvertTo-SecureString -String "my-secret-value" -AsPlainText -Force
Set-AzKeyVaultSecret -VaultName "uamidemokv01" -Name "TestSecret" -SecretValue $secretValue
```

### Step 5: Deploy to Azure

To share your application, deploy it to Azure App Service using the provided script.

**Prerequisite:** Ensure you have created the resources (Step 1) and have `azure-resources-config.json` generated.

```powershell
.\Deploy-App.ps1 `
    -SubscriptionId "your-subscription-id" `
    -ResourceGroupName "rg-uami-demo" `
    -AppName "my-uami-demo-app" `
    -Location "eastus"
```

The script will:
1. Build and publish your app locally
2. Create an App Service Plan (Linux)
3. Create the Web App
4. Configure Identity and Key Vault settings (using `azure-resources-config.json`)
5. Deploy the application code

Once complete, visit the URL output by the script (e.g., `https://my-uami-demo-app.azurewebsites.net`).

### Step 6: Delete Resources

When you're done with testing:

**Option A: Using saved config file**
```powershell
.\Delete-AzureResources.ps1 -ConfigFile "azure-resources-config.json"
```

**Option B: Using parameters**
```powershell
.\Delete-AzureResources.ps1 `
    -SubscriptionId "your-subscription-id" `
    -ResourceGroupName "rg-uami-demo"
```

**Option C: Skip confirmation**
```powershell
.\Delete-AzureResources.ps1 -ConfigFile "azure-resources-config.json" -Force
```

## What Gets Created

### User-Assigned Managed Identities (UAMIs)

| Property | Details |
|----------|---------|
| **UAMI 1** | `uami-demo-uami-01` |
| **UAMI 2** | `uami-demo-uami-02` |
| **Purpose** | Authenticate to Key Vault without storing credentials |
| **Access** | Both UAMIs can access both Key Vaults |

### Key Vaults

| Property | Details |
|----------|---------|
| **KV 1** | `uamiddemokv01` |
| **KV 2** | `uamiddemokv02` |
| **Purge Protection** | Enabled (30-day recovery) |
| **Access Level** | Get, List, Set, Delete secrets |

### Access Permissions

```
UAMI-01 ──→ KV-01 (Get, List, Set, Delete)
         └→ KV-02 (Get, List, Set, Delete)

UAMI-02 ──→ KV-01 (Get, List, Set, Delete)
         └→ KV-02 (Get, List, Set, Delete)
```

## Configuration Files

### azure-resources-config.json

Generated by Create script. Example:
```json
{
  "timestamp": "2026-03-04T10:30:00.0000000Z",
  "subscriptionId": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx",
  "resourceGroupName": "rg-uami-demo",
  "location": "eastus",
  "tenantId": "yyyyyyyy-yyyy-yyyy-yyyy-yyyyyyyyyyyy",
  "uamis": [
    {
      "name": "uami-demo-uami-01",
      "clientId": "zzzzzzzz-zzzz-zzzz-zzzz-zzzzzzzzzzzz",
      "principalId": "wwwwwwww-wwww-wwww-wwww-wwwwwwwwwwww",
      "resourceId": "/subscriptions/xxxx/resourcegroups/rg-uami-demo/providers/microsoft.managedidentity/userassignedidentities/uami-demo-uami-01"
    }
  ],
  "keyVaults": [
    {
      "name": "uamiddemokv01",
      "uri": "https://uamiddemokv01.vault.azure.net/",
      "resourceId": "/subscriptions/xxxx/resourcegroups/rg-uami-demo/providers/microsoft.keyvault/vaults/uamiddemokv01",
      "location": "eastus"
    }
  ]
}
```

### appsettings.json

Update your application settings:
```json
{
  "Azure": {
    "KeyVaultUrl": "https://uamiddemokv01.vault.azure.net/",
    "UseDefaultCredential": true,
    "TenantId": "your-tenant-id",
    "ExpectedUamiClientId": "your-uami-client-id"
  }
}
```

## Troubleshooting

### Error: "Module Az.Accounts not found"
```powershell
Install-Module -Name Az.Accounts -Force -AllowClobber -Scope CurrentUser
```

### Error: "Access Denied (403)"
- Ensure your UAMI has "Key Vault Secrets User" role assigned
- The script automatically grants this, but manual assignment may be needed:
  ```powershell
  New-AzRoleAssignment `
      -ObjectId "uami-principal-id" `
      -RoleDefinitionName "Key Vault Secrets User" `
      -Scope "/subscriptions/your-sub-id"
  ```

### Error: "Secret not found (404)"
- Verify the secret name exists in Key Vault
- Check that the correct Key Vault URI is configured
- Secrets are case-sensitive in Azure Key Vault

### Error: "Subscription ID not found"
- Get your subscription ID:
  ```powershell
  Get-AzSubscription | Select-Object Name, Id
  ```

### Key Vault Already Exists
- Key Vault names are globally unique in Azure
- If creation fails, try a different `EnvironmentPrefix`
- Or use an existing Key Vault by manually updating scripts

## Advanced Usage

### Create Resources in Multiple Regions

```powershell
# East US
.\Create-AzureResources.ps1 -SubscriptionId "sub-id" -ResourceGroupName "rg-uami-east" -Location "eastus" -EnvironmentPrefix "uami-east"

# West US
.\Create-AzureResources.ps1 -SubscriptionId "sub-id" -ResourceGroupName "rg-uami-west" -Location "westus2" -EnvironmentPrefix "uami-west"
```

### Using Existing Resource Group

The scripts will use an existing resource group if it already exists:

```powershell
.\Create-AzureResources.ps1 -SubscriptionId "sub-id" -ResourceGroupName "my-existing-rg" -Location "eastus"
```

### Verbose Output

Enable detailed logging:
```powershell
.\Create-AzureResources.ps1 -SubscriptionId "sub-id" -ResourceGroupName "rg-uami-demo" -Location "eastus" -Verbose
```

## Integration with CI/CD

### GitHub Actions Example

```yaml
name: Create Azure Resources

on:
  workflow_dispatch:
    inputs:
      environment:
        required: true
        type: choice
        options:
          - dev
          - staging
          - prod

jobs:
  create-resources:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3

      - name: Run Create Script
        shell: pwsh
        run: |
          ${{ secrets.AZURE_SUBSCRIPTION_ID }}
          .\Create-AzureResources.ps1 `
            -SubscriptionId "${{ secrets.AZURE_SUBSCRIPTION_ID }}" `
            -ResourceGroupName "rg-uami-${{ github.event.inputs.environment }}" `
            -Location "eastus" `
            -EnvironmentPrefix "uami-${{ github.event.inputs.environment }}"
```

## Security Best Practices

1. **Don't Commit Secrets** - Never commit actual secrets to Git
2. **Use Key Vault Secrets** - Store secrets in Key Vault, not in appsettings.json
3. **Rotate UAMIs** - Periodically refresh UAMI credentials
4. **Audit Access** - Monitor Key Vault access logs in Azure Monitor
5. **Least Privilege** - Only grant necessary permissions to UAMIs
6. **Environment Isolation** - Use separate Resource Groups for dev/staging/prod

## Cleanup Strategy

### Complete Cleanup
```powershell
.\Delete-AzureResources.ps1 -ConfigFile "azure-resources-config.json" -Force
Remove-AzResourceGroup -Name "rg-uami-demo" -Force
```

### Keep Resource Group, Delete Only Resources
```powershell
.\Delete-AzureResources.ps1 -ConfigFile "azure-resources-config.json" -Force
# Resource group remains for other resources
```

## Getting Help

- **Azure Documentation**: https://learn.microsoft.com/en-us/azure/
- **PowerShell Az Module**: https://learn.microsoft.com/en-us/powershell/azure/
- **UAMIDemo.Web Issues**: Check CLEANUP_SUMMARY.md and README_APP.md in the project

---

**Last Updated**: March 4, 2026
**Script Version**: 1.0
