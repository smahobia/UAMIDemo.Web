# UAMIDemo.Web – Architecture & Sequence Diagrams

This document provides architecture and sequence diagrams to help developers understand the system structure and key workflows of **UAMIDemo.Web** — a .NET 10 ASP.NET Core application that demonstrates secure Azure integration using **User-Assigned Managed Identity (UAMI)**.

---

## Table of Contents

1. [Architecture Diagram](#1-architecture-diagram)
2. [Component Descriptions](#2-component-descriptions)
3. [Sequence Diagrams](#3-sequence-diagrams)
   - [Secret Retrieval Flow](#31-secret-retrieval-flow)
   - [Azure Resource Discovery Flow](#32-azure-resource-discovery-flow-sse)
   - [Runtime Configuration Update Flow](#33-runtime-configuration-update-flow)
4. [Architectural Patterns](#4-architectural-patterns)
5. [Security Design](#5-security-design)

---

## 1. Architecture Diagram

```mermaid
graph TB
    subgraph Browser["Browser (SPA — wwwroot/index.html)"]
        UI["Interactive Setup Wizard\n───────────────────\n• Device-code login\n• Resource discovery\n• Config apply\n• Secret retrieval tester"]
    end

    subgraph API["ASP.NET Core API Layer (.NET 10)"]
        CC["ConfigController\n/api/config/*\n───────────────────\nGET  /current\nPOST /credential-mode\nPOST /apply\nGET  /discover (SSE)"]
        SC["SecretsController\n/api/secrets/*\n───────────────────\nPOST /retrieve\nGET  /health\nGET  /config"]
    end

    subgraph Services["Services Layer"]
        RCS["RuntimeConfigService\n(Singleton)\n───────────────────\n• KeyVaultUrl\n• ExpectedUamiClientId\n• TenantId\n• UseManagedIdentity\n• Thread-safe mutations"]
        KVS["KeyVaultService\n(Scoped)\n───────────────────\n• UAMI validation\n• Credential factory\n• Secret retrieval\n• Error handling"]
        IKVS["IKeyVaultService\n(Interface)"]
    end

    subgraph Config["Configuration"]
        AS["appsettings.json\nappsettings.Development.json\nappsettings.Production.json"]
        ENV["Environment Variables\nAzure__KeyVaultUrl\nAzure__ExpectedUamiClientId\nAzure__TenantId\n…"]
    end

    subgraph AzureSDK["Azure SDK (Azure.Identity)"]
        DAC["DefaultAzureCredential\n(Development)\n• az login\n• Visual Studio\n• Environment vars"]
        MIC["ManagedIdentityCredential\n(Production)\n• User-Assigned UAMI\n• System-Assigned UAMI"]
    end

    subgraph AzureServices["Azure Services"]
        KV["Azure Key Vault\nSecret storage"]
        ARM["Azure Resource Manager\nSubscription / UAMI / KV\nenumeration"]
        AAD["Microsoft Entra ID\nToken issuance"]
    end

    UI -- "HTTP / SSE" --> CC
    UI -- "HTTP" --> SC
    CC --> RCS
    CC --> ARM
    SC --> IKVS
    SC --> RCS
    IKVS --> KVS
    KVS --> RCS
    KVS --> DAC
    KVS --> MIC
    DAC -- "OAuth2 token" --> AAD
    MIC -- "IMDS token" --> AAD
    DAC --> KV
    MIC --> KV
    AS --> RCS
    ENV --> RCS
    ARM -- "Entra ID token\n(DeviceCode / DefaultAzure)" --> AAD
```

### Deployment View

```mermaid
graph LR
    subgraph Developer["Developer Machine (local)"]
        DevBrowser["Browser"]
        DevApp["ASP.NET Core App\n(Kestrel / IIS Express)\nUSES DefaultAzureCredential"]
    end

    subgraph Azure["Azure Cloud"]
        subgraph AppService["App Service / VM"]
            ProdApp["ASP.NET Core App\nUSES ManagedIdentityCredential"]
        end
        UAMI["User-Assigned\nManaged Identity"]
        KeyVault["Azure Key Vault"]
        EntraID["Microsoft Entra ID"]
        ARM2["Azure Resource Manager"]
    end

    DevBrowser --> DevApp
    DevApp -- "az login / VS credential" --> EntraID
    DevApp --> KeyVault
    ProdApp -- "UAMI token via IMDS" --> EntraID
    UAMI -- "assigned to" --> AppService
    ProdApp --> KeyVault
    ProdApp --> ARM2
    KeyVault --> EntraID
```

---

## 2. Component Descriptions

### Browser SPA (`wwwroot/index.html`)
A single-page application (37 KB) that guides users through Azure configuration without storing any credentials:
- **Setup Wizard**: Initiates device-code authentication, streams SSE events, and lets users select discovered UAMIs and Key Vaults.
- **Credential Toggle**: Switches between `ManagedIdentityCredential` (production) and `DefaultAzureCredential` (development) at runtime.
- **Secret Tester**: Retrieves secrets and shows the equivalent C# code snippet for educational purposes.

### ConfigController (`/api/config`)
Manages runtime configuration state and triggers Azure resource discovery:

| Endpoint | Method | Responsibility |
|---|---|---|
| `/api/config/current` | GET | Returns a snapshot of the live in-memory config |
| `/api/config/credential-mode` | POST | Toggles `ManagedIdentity` ↔ `DefaultAzureCredential` |
| `/api/config/apply` | POST | Persists discovered Key Vault URL, UAMI ID, Tenant ID |
| `/api/config/discover` | GET (SSE) | Streams resource discovery events to the browser |

### SecretsController (`/api/secrets`)
Handles Key Vault secret retrieval:

| Endpoint | Method | Responsibility |
|---|---|---|
| `/api/secrets/retrieve` | POST | Retrieves a named secret from Key Vault |
| `/api/secrets/health` | GET | Health check (status, timestamp, environment) |
| `/api/secrets/config` | GET | Returns the current runtime config snapshot |

### RuntimeConfigService (Singleton)
The central in-memory configuration store. Values are seeded from `appsettings.json` and environment variables at startup and may be updated live by the Setup wizard without restarting the application. All property access is protected by a `lock` for thread safety.

| Property | Purpose |
|---|---|
| `KeyVaultUrl` | Target Key Vault endpoint |
| `ExpectedUamiClientId` | Validates that requests use the authorized UAMI only |
| `TenantId` | Microsoft Entra ID tenant |
| `UseManagedIdentity` | `true` = UAMI (production), `false` = DefaultAzure (development) |

### IKeyVaultService / KeyVaultService (Scoped)
Abstracts all Azure Key Vault interactions. The interface enables unit testing with mock implementations. The concrete `KeyVaultService`:
1. Resolves the effective Key Vault URL (request override → runtime config → error).
2. Validates that the supplied UAMI matches the configured `ExpectedUamiClientId`.
3. Creates the appropriate `TokenCredential` via a factory method.
4. Calls `SecretClient.GetSecretAsync` and maps Azure exceptions to user-friendly `SecretResponse` objects.
5. Generates C# code snippets for educational display.

### Azure SDKs
- **`Azure.Identity`**: Provides `DefaultAzureCredential` (development chain) and `ManagedIdentityCredential` (production UAMI/system-assigned).
- **`Azure.Security.KeyVault.Secrets`**: `SecretClient` for reading secrets from Key Vault.
- **`Azure.ResourceManager`**: `ArmClient` for enumerating subscriptions, UAMIs, and Key Vaults during the discovery wizard.

---

## 3. Sequence Diagrams

### 3.1 Secret Retrieval Flow

```mermaid
sequenceDiagram
    actor User
    participant SPA as Browser SPA
    participant SC as SecretsController
    participant KVS as KeyVaultService
    participant RCS as RuntimeConfigService
    participant AzID as Azure Identity SDK
    participant KV as Azure Key Vault

    User->>SPA: Enter secret name + optional UAMI ID
    SPA->>SC: POST /api/secrets/retrieve\n{secretName, managedIdentityId?, keyVaultUrl?}

    SC->>SC: Validate request (secretName required)
    SC->>KVS: GetSecretAsync(secretName, managedIdentityId?, keyVaultUrlOverride?)

    KVS->>RCS: Read KeyVaultUrl, ExpectedUamiClientId, UseManagedIdentity
    RCS-->>KVS: Config values

    KVS->>KVS: Resolve effective KV URL\n(override → runtime config)

    alt UseManagedIdentity == false
        KVS->>AzID: new DefaultAzureCredential()\n(az login / VS / env)
    else UseManagedIdentity == true and UAMI ID provided
        KVS->>KVS: Validate managedIdentityId == ExpectedUamiClientId
        KVS->>AzID: new ManagedIdentityCredential(clientId)
    else UseManagedIdentity == true and no UAMI ID
        KVS->>AzID: new ManagedIdentityCredential()\n(system-assigned)
    end

    KVS->>KV: SecretClient.GetSecretAsync(secretName)

    alt Success
        KV-->>KVS: KeyVaultSecret.Value
        KVS-->>SC: SecretResponse {Success=true, SecretValue, CodeSnippet}
        SC-->>SPA: 200 OK {success, secretValue, credentialMethod, codeSnippet}
        SPA-->>User: Display secret value + code snippet
    else 403 Forbidden
        KV-->>KVS: RequestFailedException (403)
        KVS-->>SC: SecretResponse {Success=false, ErrorMessage: "Assign Key Vault Secrets User role"}
        SC-->>SPA: 200 OK {success=false, errorMessage}
        SPA-->>User: Show RBAC guidance
    else 404 Not Found
        KV-->>KVS: RequestFailedException (404)
        KVS-->>SC: SecretResponse {Success=false, ErrorMessage: "Secret not found"}
        SC-->>SPA: 200 OK {success=false, errorMessage}
        SPA-->>User: Show not-found message
    end
```

---

### 3.2 Azure Resource Discovery Flow (SSE)

```mermaid
sequenceDiagram
    actor User
    participant SPA as Browser SPA
    participant CC as ConfigController
    participant ARM as Azure Resource Manager
    participant EntraID as Microsoft Entra ID

    User->>SPA: Click "Discover Azure Resources"
    SPA->>CC: GET /api/config/discover?tenantId=... (SSE)

    CC->>CC: Set Content-Type: text/event-stream\nCreate unbounded Channel

    CC->>CC: Spawn background Task
    Note over CC: Background task enumerates resources\nand writes to Channel

    CC-->>SPA: SSE event: progress\n"Authenticating with Azure…"

    CC->>EntraID: DefaultAzureCredential\n(az login / Visual Studio / environment)
    EntraID-->>CC: Access token

    CC->>ARM: GetSubscriptions().GetAllAsync()

    alt Authentication Fails
        ARM-->>CC: AuthenticationFailedException
        CC-->>SPA: SSE event: error {message: "Run az login first"}
    else Success
        ARM-->>CC: Subscription list
        CC-->>SPA: SSE event: subscriptions\n{data: [{id, name, tenantId}]}

        CC->>ARM: GetUserAssignedIdentitiesAsync()
        ARM-->>CC: UAMI list
        CC-->>SPA: SSE event: identities\n{data: [{name, clientId, principalId, resourceGroup}]}

        CC->>ARM: GetKeyVaultsAsync()
        ARM-->>CC: Key Vault list
        CC-->>SPA: SSE event: key-vaults\n{data: [{name, url, resourceGroup, location}]}

        CC-->>SPA: SSE event: complete\n{tenantId, subscriptionId}
    end

    SPA->>User: Display discovered UAMIs and Key Vaults\nfor selection
    User->>SPA: Select UAMI + Key Vault, click "Apply"
    SPA->>CC: POST /api/config/apply\n{keyVaultUrl, expectedUamiClientId, tenantId, useManagedIdentity}
    CC->>CC: RuntimeConfigService.Apply(...)
    CC-->>SPA: 200 OK {success, config snapshot}
    SPA-->>User: Configuration saved ✓
```

---

### 3.3 Runtime Configuration Update Flow

```mermaid
sequenceDiagram
    actor DevOps
    participant SPA as Browser SPA
    participant CC as ConfigController
    participant RCS as RuntimeConfigService

    note over DevOps,RCS: Toggle credential mode (dev ↔ prod)
    DevOps->>SPA: Toggle "Use Managed Identity" switch
    SPA->>CC: POST /api/config/credential-mode\n{useManagedIdentity: true|false}
    CC->>RCS: SetCredentialMode(useManagedIdentity)
    RCS->>RCS: lock → _useManagedIdentity = value
    CC-->>SPA: 200 OK {success, useManagedIdentity}
    SPA-->>DevOps: Mode indicator updated

    note over DevOps,RCS: Read current config
    DevOps->>SPA: Open config panel
    SPA->>CC: GET /api/config/current
    CC->>RCS: Snapshot()
    RCS-->>CC: {keyVaultUrl, expectedUamiClientId, tenantId,\nuseManagedIdentity, validationEnabled, isConfigured}
    CC-->>SPA: 200 OK config JSON
    SPA-->>DevOps: Display current settings
```

---

## 4. Architectural Patterns

| Pattern | Where Used | Benefit |
|---|---|---|
| **Dependency Injection** | Controllers inject `IKeyVaultService`, `RuntimeConfigService`; services inject `IOptions<AzureSettings>` | Loose coupling, testability via interface substitution |
| **Interface Abstraction (Repository-like)** | `IKeyVaultService` decouples controllers from Azure SDK | Enables unit testing with mock implementations |
| **Singleton for Shared Mutable State** | `RuntimeConfigService` registered as `AddSingleton` | Live config changes propagate immediately to all request handlers without app restart |
| **Strategy Pattern** | `KeyVaultService.CreateSecretClient()` selects `DefaultAzureCredential` or `ManagedIdentityCredential` based on mode | Supports both local development and production UAMI auth without code changes |
| **Factory Method** | `CreateSecretClient()` creates `SecretClient` with the correct credential | Encapsulates credential construction; client is always created fresh per request to pick up latest config |
| **Observer / Push via SSE** | `ConfigController.Discover()` uses `System.Threading.Channels` + SSE | Decouples long-running discovery work from the HTTP response stream; provides real-time progress without polling |
| **Options Pattern** | `IOptions<AzureSettings>` bound to `appsettings.json` `"Azure"` section | Structured configuration, validated at startup |
| **Placeholder Guard** | `RuntimeConfigService.IsReal()` ignores values starting with `<` | Prevents accidental use of template placeholder strings as real Azure configuration |

---

## 5. Security Design

| Concern | Design Decision |
|---|---|
| **No secrets in source** | `appsettings.json` holds only `<placeholder>` values. Real values come from OS environment variables or the in-memory discovery wizard. |
| **UAMI identity validation** | `KeyVaultService` compares the supplied `managedIdentityId` against `ExpectedUamiClientId`. Mismatches are rejected before any Azure call is made. |
| **Credential isolation** | Development uses `DefaultAzureCredential` (IMDS excluded to prevent hangs). Production uses `ManagedIdentityCredential` only. |
| **RBAC guidance** | A `403` from Key Vault produces a human-readable message prompting the user to assign the `Key Vault Secrets User` role. |
| **Thread-safe state** | All `RuntimeConfigService` reads/writes are protected by a `lock` object, preventing race conditions during concurrent requests. |
| **No browser credential storage** | The discovery wizard stores selected values in the server's in-memory `RuntimeConfigService` only; nothing is persisted to disk or cookies. |
