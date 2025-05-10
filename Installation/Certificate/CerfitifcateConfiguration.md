# Azure Application Certificate Authentication Setup Guide

This guide explains how to set up certificate-based authentication for an Azure application to securely access Key Vault.

## Prerequisites

* An Azure subscription
* Azure CLI installed
* PowerShell 7.0 or later
* OpenSSL (for certificate generation)

## Step 1: Create a Self-Signed Certificate

You can create a self-signed certificate for development/testing or use a certificate from a trusted Certificate Authority for production environments.

### Using PowerShell to generate a self-signed certificate:

```powershell
# Define certificate parameters
$configPath = "..\..\environments\dev.json" # Adjust the path as needed
$config = Get-Content -Path $configPath | ConvertFrom-Json

$certName = "OrchestratorPshKv"
$certPassword = ConvertTo-SecureString -String "" -Force -AsPlainText # See KeePass OrchestratorPshCertPassword
$certPath = ".\$($config.certName)$.pfx"
$certThumbprint = $null

# Create self-signed certificate valid for 2 years
$cert = New-SelfSignedCertificate -CertStoreLocation Cert:\CurrentUser\My `
    -Subject "CN=$certName" `
    -KeySpec Signature `
    -NotAfter (Get-Date).AddYears(2) `
    -KeyExportPolicy Exportable `
    -KeyAlgorithm RSA `
    -KeyLength 2048

$certThumbprint = $cert.Thumbprint

# Export PFX
Export-PfxCertificate -Cert "Cert:\CurrentUser\My\$certThumbprint" -FilePath $certPath -Password $certPassword

# Export CER (public key)
Export-Certificate -Cert "Cert:\CurrentUser\My\$certThumbprint" -FilePath ".\$certName.cer"

Write-Host "Certificate created with thumbprint: $certThumbprint"
```



### PowerShell Example

```powershell
# Define parameters
$tenantId = "your-tenant-id"
$clientId = "your-client-id"
$certThumbprint = "your-cert-thumbprint"
$keyVaultName = "your-keyvault-name"

# Connect using certificate
Connect-AzAccount -ServicePrincipal -CertificateThumbprint $certThumbprint -ApplicationId $clientId -TenantId $tenantId

# Access Key Vault
$secret = Get-AzKeyVaultSecret -VaultName $keyVaultName -Name "MySecret"
```

### C# Example

```csharp
// Add NuGet packages:
// - Azure.Identity
// - Azure.Security.KeyVault.Secrets

using Azure.Identity;
using Azure.Security.KeyVault.Secrets;
using System;
using System.Security.Cryptography.X509Certificates;

// Certificate can be loaded from:
// - Certificate store: new X509Certificate2(thumbprint)
// - File: new X509Certificate2("path/to/cert.pfx", "password")
var certificate = new X509Certificate2("path/to/cert.pfx", "password");

var clientId = "your-client-id";
var tenantId = "your-tenant-id";
var keyVaultUrl = "https://your-keyvault-name.vault.azure.net/";

// Create client using certificate authentication
var credential = new ClientCertificateCredential(tenantId, clientId, certificate);
var client = new SecretClient(new Uri(keyVaultUrl), credential);

// Retrieve a secret
KeyVaultSecret secret = client.GetSecret("MySecret");
Console.WriteLine($"Secret value: {secret.Value}");
```

## Step 7: Deploy Certificate in Azure App Service (if applicable)

1. In Azure portal, navigate to your App Service
2. Go to **TLS/SSL settings** > **Private Key Certificates (.pfx)**
3. Click **Upload Certificate**
4. Upload the .pfx file with the password
5. Click **Upload**

Then configure the application to use the certificate:

1. Go to **Configuration** > **Application settings**
2. Add these settings:
   - WEBSITE_LOAD_CERTIFICATES: [your-cert-thumbprint]
   - AZURE_CLIENT_ID: [your-app-registration-client-id]
   - AZURE_TENANT_ID: [your-tenant-id]
3. Click **Save**

## Security Best Practices

1. **Managed Identity**: For resources that support it, use Managed Identity instead of certificates when possible
2. **Certificate Rotation**: Implement a process for rotating certificates before they expire
3. **Secret Management**: Never hard-code certificates or passwords in your application
4. **Least Privilege**: Grant only necessary permissions in Key Vault access policies
5. **Monitoring**: Set up alerts for certificate expiration and access failures
6. **Network Security**: Restrict Key Vault access to specific networks when possible
7. **Soft Delete**: Enable soft-delete and purge protection for Key Vault

## Troubleshooting

- **Certificate Not Found**: Ensure the certificate is properly uploaded or installed
- **Access Denied**: Verify access policies are correctly set in Key Vault
- **Certificate Expired**: Check certificate expiration date and renew if needed
- **Wrong Thumbprint**: Verify the thumbprint matches between code and certificate

## Alternative Authentication Methods

- **Managed Identity**: Preferred for Azure resources that support it
- **Client Secret**: Less secure alternative to certificates
- **User-delegated authentication**: For applications acting on behalf of users

For production environments, Managed Identity is recommended when available as it eliminates the need to manage certificates or secrets.

