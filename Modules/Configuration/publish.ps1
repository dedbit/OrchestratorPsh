# publish.ps1
# Script to publish the messaging package to a NuGet feed

# Todo:
# If artifacts feed already exists it fails. 

# Import the Az module to interact with Azure services
# Import-Module Az

# Function to ensure NuGet feed is configured
function Ensure-NuGetFeedConfigured {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$FeedName,

        [Parameter(Mandatory=$true)]
        [string]$FeedUrl,

        [Parameter(Mandatory=$true)]
        [string]$PAT
    )

    Write-Host "Ensuring NuGet source '$FeedName' is correctly configured..." -ForegroundColor Cyan

    # Check if the source already exists
    Write-Host "Checking if NuGet source '$FeedName' already exists..."
    $sourceExistsOutput = nuget sources list -Name $FeedName -Format Short
    $sourceFound = $false
    if ($LASTEXITCODE -eq 0 -and $sourceExistsOutput) {
        # nuget sources list with -Name will output the source name if found, or nothing if not.
        # We need to be careful as $sourceExistsOutput could be an array of strings or a single string.
        if ($sourceExistsOutput -is [array]) {
            if ($sourceExistsOutput -join '`n' -match [regex]::Escape($FeedName)) {
                $sourceFound = $true
            }
        } elseif ($sourceExistsOutput -is [string] -and $sourceExistsOutput -match [regex]::Escape($FeedName)) {
            $sourceFound = $true
        }
    }

    if ($sourceFound) {
        Write-Host "NuGet source '$FeedName' found. Removing it before re-adding..." -ForegroundColor Yellow
        nuget sources remove -Name $FeedName
        if ($LASTEXITCODE -ne 0) {
            Write-Warning "Failed to remove existing NuGet source '$FeedName'. Attempting to add it anyway."
        }
    } else {
        Write-Host "NuGet source '$FeedName' not found. Proceeding to add."
    }

    # Add the source
    nuget sources add -Name $FeedName -Source $FeedUrl -Username "AzureDevOps" -Password $PAT -StorePasswordInClearText
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Failed to add NuGet source '$FeedName'. NuGet exited with code $LASTEXITCODE."
        # It might be prudent to exit here if adding the source fails, as subsequent operations will likely fail.
        exit $LASTEXITCODE 
    }
    Write-Host "NuGet source '$FeedName' configured." -ForegroundColor Green
}


# Set the NuGet source name and package variables for ConfigurationPackage
$ArtifactsFeed = "OrchestratorPshRepo"
$SecretName = "PAT"   # Replace with the name of the secret storing the PAT
$PackageName = "ConfigurationPackage"


# Define variables at the top
$envConfigPath = Join-Path ($PSScriptRoot ? $PSScriptRoot : (Get-Location).Path) '..\..\environments\dev.json'
$configModulePath = Join-Path ($PSScriptRoot ? $PSScriptRoot : (Get-Location).Path) 'ConfigurationPackage/ConfigurationPackage.psd1'
$azureModulePath = Join-Path ($PSScriptRoot ? $PSScriptRoot : (Get-Location).Path) '../OrchestratorAzure/OrchestratorAzure.psd1'

 
Import-Module $configModulePath
Import-Module $azureModulePath
Initialize-12Configuration $envConfigPath
Connect-12Azure


# Import OrchestratorCommon module
$moduleRoot = Join-Path ($PSScriptRoot ? $PSScriptRoot : (Get-Location).Path) -ChildPath "..\OrchestratorCommon" # Applied robust path pattern
if (Test-Path $moduleRoot) {
    Import-Module $moduleRoot -Force
    Write-Host "OrchestratorCommon module imported successfully." -ForegroundColor Green
} else {
    Write-Error "OrchestratorCommon module not found at $moduleRoot. Make sure the module is installed correctly."
    exit 1
}

# Get the package version from the nuspec file
$packagePath = Join-Path ($PSScriptRoot ? $PSScriptRoot : (Get-Location).Path) 'ConfigurationPackage.nuspec'

$nuspecContent = Get-Content $packagePath -Raw
if ($nuspecContent -match '<version>([0-9]+)\.([0-9]+)\.([0-9]+)</version>') {
    $major = $matches[1]
    $minor = $matches[2]
    $patch = $matches[3]
    $version = "$major.$minor.$patch"
    Write-Host "Package version from nuspec: $version" -ForegroundColor Cyan
} else {
    Write-Error "Failed to find version in nuspec file."
    exit 1
}



# Detect the latest package in the output directory
$outputDirectory = Join-Path ($PSScriptRoot ? $PSScriptRoot : (Get-Location).Path) '..\..\Output'
$PackagePath = Join-Path -Path $outputDirectory -ChildPath ("$PackageName.$version.nupkg")
Write-Host "Using package path: $PackagePath" -ForegroundColor Cyan

# Verify the package exists
if (-not (Test-Path $PackagePath)) {
    Write-Error "Package not found at $PackagePath. Please build the package first."
    exit 1
}

Write-Host "Publishing package $PackagePath..." -ForegroundColor Cyan

# Retrieve the PAT securely
# Access configuration values from the globally initialized configuration
# Initialize-12Configuration stores config in $Global:12cConfig
$KeyVaultName = $Global:12cConfig.keyVaultName
$TenantId = $Global:12cConfig.tenantId
$SubscriptionId = $Global:12cConfig.subscriptionId
$ArtifactsFeedUrl = $Global:12cConfig.artifactsFeedUrl 

# Check if essential config values were found
if ([string]::IsNullOrEmpty($KeyVaultName) -or [string]::IsNullOrEmpty($TenantId) -or [string]::IsNullOrEmpty($SubscriptionId) -or [string]::IsNullOrEmpty($ArtifactsFeedUrl)) {
    Write-Error "One or more required configuration values (KeyVaultName, TenantId, SubscriptionId, ArtifactsFeedUrl) could not be retrieved from the global configuration (expected in \$Global:12cConfig). Ensure Initialize-12Configuration has run successfully and set them."
    exit 1
}

Write-Host "Retrieving PAT from Key Vault: $KeyVaultName" -ForegroundColor Cyan
$PersonalAccessToken = Get-PATFromKeyVault -KeyVaultName $KeyVaultName -SecretName $SecretName -TenantId $TenantId -SubscriptionId $SubscriptionId

# Check if PAT was retrieved successfully
if ([string]::IsNullOrEmpty($PersonalAccessToken)) {
    Write-Error "Failed to retrieve Personal Access Token from Key Vault. Aborting."
    exit 1
}

# Set up the NuGet source with the PAT
Ensure-NuGetFeedConfigured -FeedName $ArtifactsFeed -FeedUrl $ArtifactsFeedUrl -PAT $PersonalAccessToken

# Check if nuget sources add was successful - $LASTEXITCODE might not be reliable for 'nuget sources add'
# A more robust check would be to list sources and verify, but for now, we'll assume if no error is thrown by nuget, it's okay.

# Publish the package
Write-Host "Pushing package to feed..." -ForegroundColor Cyan
nuget push $PackagePath -Source $ArtifactsFeed -ApiKey "AzureDevOps"

# Check if nuget push was successful
if ($LASTEXITCODE -ne 0) {
    Write-Error "Failed to publish NuGet package. NuGet exited with code $LASTEXITCODE."
    # Attempt to clean up the NuGet source even if push failed
    Write-Host "Attempting to clean up NuGet source after failed push..." -ForegroundColor Yellow
    nuget sources remove -Name $ArtifactsFeed
    exit $LASTEXITCODE
}

# Clean up the NuGet source to remove sensitive information
Write-Host "Cleaning up NuGet source after successful push..." -ForegroundColor Cyan
nuget sources remove -Name $ArtifactsFeed

Write-Host "Package published successfully!" -ForegroundColor Green

