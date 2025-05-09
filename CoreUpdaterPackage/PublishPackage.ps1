# Import the Az module to interact with Azure services
Import-Module Az

# Function to retrieve the Personal Access Token (PAT) from Azure Key Vault
function Get-PATFromKeyVault {
    param (
        [string]$KeyVaultName,
        [string]$SecretName
    )

    # Login to Azure (if not already logged in)
    Connect-AzAccount -ErrorAction Stop

    # Retrieve the secret from Azure Key Vault
    $secret = Get-AzKeyVaultSecret -VaultName $KeyVaultName -Name $SecretName -ErrorAction Stop
    return $secret.SecretValueText
}

# Define variables
$KeyVaultName = "YourKeyVaultName"  # Replace with your Azure Key Vault name
$SecretName = "YourPATSecretName"   # Replace with the name of the secret storing the PAT
$PackagePath = "./Output/CoreUpdaterPackage.1.0.4.nupkg"  # Path to the package
$ArtifactsFeedUrl = "https://pkgs.dev.azure.com/YourOrg/_packaging/YourFeed/nuget/v3/index.json"  # Replace with your feed URL

# Retrieve the PAT securely
$PersonalAccessToken = Get-PATFromKeyVault -KeyVaultName $KeyVaultName -SecretName $SecretName

# Set up the NuGet source with the PAT
nuget.exe sources add -Name "ArtifactsFeed" -Source $ArtifactsFeedUrl -Username "AzureDevOps" -Password $PersonalAccessToken -StorePasswordInClearText

# Publish the package
nuget.exe push $PackagePath -Source "ArtifactsFeed" -ApiKey "AzureDevOps"

# Clean up the NuGet source to remove sensitive information
nuget.exe sources remove -Name "ArtifactsFeed"