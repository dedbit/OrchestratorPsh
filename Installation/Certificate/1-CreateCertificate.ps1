# Define certificate parameters

$configPath = "..\..\environments\dev.json" # Adjust the path as needed
$config = Get-Content -Path $configPath | ConvertFrom-Json


# Request password input from the user
$certPassword = Read-Host -Prompt "Enter certificate password" 

$certPath = ".\$($config.certName).pfx"
$certThumbprint = $null

# Create self-signed certificate valid for 2 years
$cert = New-SelfSignedCertificate -CertStoreLocation Cert:\CurrentUser\My `
    -Subject "CN=$($config.certName)" `
    -KeySpec Signature `
    -NotAfter (Get-Date).AddYears($($config.expiryYears)) `
    -KeyExportPolicy Exportable `
    -KeyAlgorithm RSA `
    -KeyLength 2048

$certThumbprint = $cert.Thumbprint

# Export PFX
Export-PfxCertificate -Cert "Cert:\CurrentUser\My\$certThumbprint" -FilePath $certPath -Password $certPassword

# Export CER (public key)
Export-Certificate -Cert "Cert:\CurrentUser\My\$certThumbprint" -FilePath ".\$($config.CertName).cer"

Write-Host "Certificate created with thumbprint: $certThumbprint"