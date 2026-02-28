# UAMIDemo.Web - Application Documentation

## Overview
**UAMIDemo.Web** is a .NET 8 ASP.NET Core web application that demonstrates secure integration with Azure services using **User-Assigned Managed Identity (UAMI)**. The application showcases best practices for managing Azure resources and retrieving secrets from Azure Key Vault without storing credentials in code.

## Key Features
- ✅ **User-Assigned Managed Identity (UAMI) Integration**: Secure authentication to Azure services
- ✅ **Azure Key Vault Integration**: Secure secret management and retrieval
- ✅ **Azure Resource Management**: Interact with Azure resources programmatically
- ✅ **Runtime Configuration**: Dynamic credential and configuration management
- ✅ **RESTful APIs**: Clean API endpoints for configuration and secret management
- ✅ **Environment-specific Configuration**: Support for Development, Staging, and Production environments

## Application Structure

```
UAMIDemo.Web/
├── Controllers/
│   ├── ConfigController.cs       # Configuration management endpoints
│   └── SecretsController.cs      # Secret management endpoints
├── Services/
│   ├── IKeyVaultService.cs       # Key Vault abstraction
│   ├── KeyVaultService.cs        # Key Vault implementation
│   ├── IAzureResourceService.cs  # Azure resource abstraction
│   ├── AzureResourceService.cs   # Azure resource implementation
│   └── RuntimeConfigService.cs   # Runtime configuration management
├── Models/
│   ├── AzureSettings.cs          # Azure configuration model
│   ├── AzureResourceModels.cs    # Azure resource models
│   ├── ConfigModels.cs           # Configuration request/response models
│   └── SecretModels.cs           # Secret request/response models
├── Pages/                         # Razor Pages (frontend)
├── wwwroot/                       # Static files (CSS, JS, images)
├── Properties/                    # Project properties and launch settings
├── Program.cs                     # Application startup and DI configuration
├── appsettings.json              # Base configuration (USE PLACEHOLDERS)
├── appsettings.Development.json  # Development settings
├── appsettings.Production.json   # Production settings
└── UAMIDemo.Web.csproj           # Project file
```

## Technical Stack
- **Framework**: ASP.NET Core (.NET 8)
- **Language**: C#
- **Authentication**: Azure Managed Identity
- **Cloud Platform**: Microsoft Azure
- **Key Libraries**:
  - `Azure.Identity`: For UAMI authentication
  - `Azure.Security.KeyVault.Secrets`: For Key Vault access
  - `Azure.ResourceManager`: For Azure resource management

## Configuration

### appsettings.json Structure
```json
{
  "Logging": {
    "LogLevel": {
      "Default": "Information",
      "Microsoft.AspNetCore": "Warning"
    }
  },
  "Azure": {
    "KeyVaultUrl": "https://<your-keyvault-name>.vault.azure.net/",
    "UseDefaultCredential": true,
    "TenantId": "<your-tenant-id>",
    "ClientId": "<your-client-id>",
    "ClientSecret": "<your-client-secret>",
    "ExpectedUamiClientId": "<your-uami-client-id>"
  },
  "AllowedHosts": "*"
}
```

**Important**: Always use placeholder values for sensitive configuration. Never commit real credentials to the repository.

## Getting Started

### Prerequisites
- [.NET 8 SDK](https://dotnet.microsoft.com/download)
- [Visual Studio 2022](https://visualstudio.microsoft.com/) or [Visual Studio Code](https://code.visualstudio.com/)
- Azure subscription
- Azure CLI (for setup)

### Local Development Setup

1. **Clone the Repository**
   ```bash
   git clone <repository-url>
   cd UAMIDemo
   ```

2. **Update Configuration**
   - Edit `UAMIDemo.Web/appsettings.Development.json`
   - Set your Key Vault URL: `https://<your-keyvault-name>.vault.azure.net/`

3. **Build the Application**
   ```bash
   dotnet build
   ```

4. **Run the Application**
   ```bash
   dotnet run
   ```
   - Application runs on: `https://localhost:58067` and `http://localhost:58068`

### Azure Setup
Refer to **LOCAL_SETUP.md** for detailed Azure resource configuration including:
- Creating an Azure Key Vault
- Setting up a User-Assigned Managed Identity
- Configuring proper Azure RBAC permissions
- Adding secrets to Key Vault

## API Endpoints

### Configuration Endpoints (`/api/config`)
- `GET /api/config` - Get current configuration
- `POST /api/config` - Update configuration
- `POST /api/config/validate` - Validate configuration

### Secrets Endpoints (`/api/secrets`)
- `GET /api/secrets` - List available secrets
- `GET /api/secrets/{name}` - Retrieve a specific secret
- `POST /api/secrets` - Add a new secret
- `DELETE /api/secrets/{name}` - Delete a secret

## Security Best Practices

✅ **Implemented**
- Credentials not stored in code
- Use of Managed Identity for Azure authentication
- Runtime-only credential management (no disk persistence)
- Environment-based configuration

⚠️ **Important for Production**
- Enable HTTPS only
- Use User-Assigned Managed Identity (UAMI) instead of credentials
- Implement proper Azure RBAC permissions
- Enable Key Vault network restrictions
- Use Azure Application Insights for monitoring
- Enable Azure Security Center recommendations

## Building and Deployment

### Build
```bash
dotnet build
```

### Clean Build Artifacts
```bash
dotnet clean
```

### Publish for Deployment
```bash
dotnet publish -c Release
```

For detailed deployment instructions, see **DEPLOYMENT.md**.

## Troubleshooting

### Application Won't Start
- Verify .NET 8 SDK is installed: `dotnet --version`
- Check Azure credentials and configuration in appsettings
- Review logs in Output window (Development mode shows detailed errors)

### Key Vault Access Issues
- Verify UAMI is assigned the correct roles in Key Vault
- Check Key Vault firewall rules allow your current IP (if enabled)
- Verify Key Vault URL is correct in configuration

### Configuration Issues
- Ensure all required settings in `appsettings.json` are properly set
- Check `appsettings.Development.json` overrides for local development
- Validate JSON syntax in configuration files

## Documentation
- **README.md** - Project overview (this file)
- **GETTING_STARTED.md** - Quick start guide
- **LOCAL_SETUP.md** - Local development environment setup
- **DEPLOYMENT.md** - Production deployment procedures
- **ARCHITECTURE.md** - Detailed application architecture
- **PROJECT_VERIFICATION.md** - Testing and verification procedures
- **DEMO_SCENARIOS.md** - Demonstration scenarios and walkthroughs

## Development Workflow

### Adding New Features
1. Create feature branch: `git checkout -b feature/my-feature`
2. Implement changes following the existing code style
3. Build and test locally: `dotnet build && dotnet run`
4. Commit with descriptive messages
5. Submit pull request

### Code Standards
- Use async/await for I/O operations
- Follow C# naming conventions
- Add XML documentation comments for public APIs
- Use dependency injection for loose coupling
- Keep controllers thin; business logic in services

## Support
For issues, questions, or contributions, please refer to the repository's issue tracker or documentation.

## License
[Add your license information here]

---

**Last Updated**: February 2026
**Framework**: .NET 8
**Target Audience**: Azure developers learning UAMI authentication
