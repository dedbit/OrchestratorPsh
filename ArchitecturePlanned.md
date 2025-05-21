### **Project Overview**

A PowerShell-based system to update local PowerShell modules by checking and downloading the latest NuGet package versions from an Azure DevOps Artifacts feed.

* * *

### **System Architecture**

A scheduled script authenticates using a certificate, retrieves secrets and package info from Azure Key Vault, checks for updates in Azure DevOps Artifacts, and installs newer packages if available.

```Mermaid
    graph TD
    subgraph "Core Components"
        U[Updater Service] 
        W[Worker Service]
    end
    
    subgraph "Authentication"
        C[Certificate-based Auth]
    end
    
    subgraph "Azure Resources"
        KV[Azure Key Vault]
        ADO[Azure DevOps Artifacts Feed]
    end
    
    subgraph "Local Resources"
        PS[PowerShell Modules Folder]
        S[Scheduled Task]
    end
    
    S --> U
    U --> C
    W --> C
    C --> KV
    KV -->|PAT| U
    KV -->|Package List| U
    KV -->|Secrets| W
    U --> ADO
    U --> PS
    W --> PS
    W --> ADO

```

* * *

### **Technology Stack**

- PowerShell 7
- Azure Key Vault
- Azure AD App Registration (with certificate)
- Azure DevOps Artifacts
- NuGet CLI (`nuget.exe`)
- Windows Task Scheduler (or alternative executor)

* * *

### **Modules and Components**

- **Updater Module**: Compares and installs new versions of NuGet packages.
- **Build Script**: Creates NuGet packages from PowerShell module source folders.
- **Publish Script**: Pushes compiled NuGet packages to the Azure DevOps feed.
- **Key Vault Access**: Fetches secrets securely using certificate authentication.

* * *

### **Data Flow**

Secrets and config are pulled from Key Vault, used to authenticate against DevOps, then newer packages are downloaded and installed if needed.

* * *

### **Security Considerations**

Certificate-based authentication is used for unattended execution, and all sensitive data (PAT, package list) is stored securely in Azure Key Vault.

* * *

### **Connections & Accesses**

- **Azure Key Vault** – *Certificate Auth*: Fetches PAT and NuGet package list.
- **Azure DevOps Artifacts Feed** – *PAT via NuGet CLI*: Accesses and downloads NuGet packages.
- **Local File System** – *No auth*: Stores installed PowerShell modules.

* * *

### **Data Stores & Configurations**

- **Azure Key Vault**: Stores PAT and the JSON list of NuGet packages to monitor.
- **Distribution Folder**: Contains locally built `.nupkg` files for publishing.
- **Windows Certificate Store**: Stores the certificate used for app authentication.