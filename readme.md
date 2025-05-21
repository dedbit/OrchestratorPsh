# Readme



# Todo

1. **Store Secrets in Azure Key Vault**
    - Add the PAT and package list JSON as secrets.

2. **Create Azure AD App Registration**
    - Register an app and upload the certificate for authentication.

3. **Install Certificate on Target Machine**
    - Import the private key used for authentication.

4. **Develop Updater Script**
    - Authenticate with certificate.
    - Fetch secrets (PAT, package list).
    - Check latest versions in Azure DevOps feed.
    - Compare and install updates.

5. **Develop Build Script**
    - Package PowerShell modules into NuGet `.nupkg` files.
    - Automatically bump version based on `package.json`.
    - Delete old `.nupkg` files in the dist folder.

6. **Develop Publish Script**
    - Push `.nupkg` to Azure DevOps Artifacts using the PAT.

7. **Schedule Execution**
    - Set up a Windows Task Scheduler or automation tool to run the updater regularly.

8. **Configure Local Module Installation Path**
    - Ensure consistent install location for updated modules.

9. **Logging and Error Handling**
    - Implement logging and capture errors during each step.

10. **Validate and Test End-to-End Flow**
- Run full process from secret retrieval to update to verify behavior.