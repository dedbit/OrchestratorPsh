# set-nuget-packages-secret.ps1
# Helper script to upload the NuGet package list to Azure Key Vault as a secret

param(
    [string]$KeyVaultName,
    [string]$PackagesListPath = "../CoreUpdaterPackage/packages.json",
    [string]$SecretName = "NugetPackagesList"
)

if (-not (Test-Path $PackagesListPath)) {
    Write-Error "Could not find packages list at $PackagesListPath."
    exit 1
}

$packagesJson = Get-Content -Path $PackagesListPath -Raw

Write-Host "Uploading package list to Key Vault '$KeyVaultName' as secret '$SecretName'..." -ForegroundColor Yellow
Set-AzKeyVaultSecret -VaultName $KeyVaultName -Name $SecretName -SecretValue (ConvertTo-SecureString $packagesJson -AsPlainText -Force)
Write-Host "Package list uploaded successfully." -ForegroundColor Green
