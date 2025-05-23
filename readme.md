# Azure Infrastructure Deployment

## Prerequisites

### Install Bicep CLI
Bicep is required to deploy the Azure infrastructure in this project.
After installation, you may need to restart your terminal for the PATH to update. 

```powershell
winget install -e --id Microsoft.Bicep
# Verify installation
bicep --version
```

### Azure PowerShell Module
The Azure PowerShell module is required to interact with Azure resources programmatically, such as managing infrastructure and automating deployment tasks.
```powershell
# Install Azure PowerShell module if not already installed
if (-not (Get-Module -ListAvailable Az)) {
    Install-Module -Name Az -Scope CurrentUser -Repository PSGallery -Force
}
```
# Completed Tasks

1. **Store Secrets in Azure Key Vault**
1. **Store Secrets in Azure Key Vault**
    - Add the PAT and package list JSON as secrets.
    Done.

2. **Create Azure AD App Registration**
    - Register an app and upload the certificate for authentication.
    Done. AppId is found in environments/dev.json.

3. **Install Certificate on Target Machine**
    - Import the private key used for authentication.
    Done. Storing certificate in Azure Key Vault. Installed on fm personal certs.

1. **Develop Updater Script**
    - Authenticate with certificate.
    - Fetch secrets (PAT, package list).
    - Check latest versions in Azure DevOps feed.
    - Compare and install updates.

2. **Develop Build Script**
    - Package PowerShell modules into NuGet `.nupkg` files.
    - Automatically bump version based on `package.json`.
    - Delete old `.nupkg` files in the dist folder.

3. **Develop Publish Script**
    - Push `.nupkg` to Azure DevOps Artifacts using the PAT.

4. **Schedule Execution**
    - Set up a Windows Task Scheduler or automation tool to run the updater regularly.

5. **Configure Local Module Installation Path**
    - Ensure consistent install location for updated modules.

6. **Logging and Error Handling**
    - Implement simple logging using serilog. Setup log rotation of 7 days. 

7. **Validate and Test End-to-End Flow**
    - Manually test  full process from secret retrieval to update to verify behavior.