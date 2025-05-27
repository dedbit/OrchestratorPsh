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


# --- Script Parameters & Static Configuration ---
$ArtifactsFeed = "OrchestratorPshRepo"
$SecretName = "PAT"   # Name of the secret in Key Vault storing the PAT
$PackageName = "ConfigurationPackage" # Base name of the package

# --- Path Definitions ---
$basePath = ($PSScriptRoot ? $PSScriptRoot : (Get-Location).Path) # Base path for relative calculations

$envConfigPath = Join-Path $basePath "..\..\environments\dev.json"
$configModulePsd1 = Join-Path $basePath "ConfigurationPackage\ConfigurationPackage.psd1" # Changed to backslash for consistency
$azureModulePsd1 = Join-Path $basePath "..\OrchestratorAzure\OrchestratorAzure.psd1"
$commonModuleRootPath = Join-Path $basePath "..\OrchestratorCommon"
$nuspecFilePath = Join-Path $basePath "ConfigurationPackage.nuspec" # Ensure this is treated as a file
$outputDirectory = Join-Path $basePath "..\..\Output"

# --- Package Version Extraction ---
Write-Host "Reading package version from: $nuspecFilePath" -ForegroundColor Cyan
if (-not (Test-Path $nuspecFilePath)) {
    Write-Error "Nuspec file not found at $nuspecFilePath. Please build the package first or check the path."
    exit 1
}
$nuspecContent = Get-Content $nuspecFilePath -Raw
# Use double quotes for the regex string and escape backslashes for PowerShell regex.
if ($nuspecContent -match "<version>([0-9]+)\.([0-9]+)\.([0-9]+)</version>") {
    $major = $matches[1]
    $minor = $matches[2]
    $patch = $matches[3]
    $version = "$major.$minor.$patch"
    Write-Host "Package version from nuspec: $version" -ForegroundColor Cyan
} else {
    Write-Error "Failed to find version in nuspec file: $nuspecFilePath"
    exit 1
}

# --- Final Package Path Construction ---
$nupkgFilePath = Join-Path -Path $outputDirectory -ChildPath ("$PackageName.$version.nupkg")
Write-Host "Expected package location: $nupkgFilePath" -ForegroundColor Cyan

# --- Module Imports & Initialization ---
Import-Module $configModulePsd1
Import-Module $azureModulePsd1
Initialize-12Configuration $envConfigPath # Uses $envConfigPath
Connect-12Azure

# Import OrchestratorCommon module
if (Test-Path $commonModuleRootPath) {
    Import-Module $commonModuleRootPath -Force
    Write-Host "OrchestratorCommon module imported successfully." -ForegroundColor Green
} else {
    Write-Error "OrchestratorCommon module not found at $commonModuleRootPath. Make sure the module is installed correctly."
    exit 1
}

# --- Main Script Logic ---

# Verify the package exists
if (-not (Test-Path $nupkgFilePath)) {
    Write-Error "Package not found at $nupkgFilePath. Please build the package first."
    exit 1
}

Write-Host "Publishing package $nupkgFilePath..." -ForegroundColor Cyan

# Retrieve the PAT securely
# Access configuration values from the globally initialized configuration
# Initialize-12Configuration stores config in $Global:12cConfig
$KeyVaultName = $Global:12cConfig.keyVaultName
$TenantId = $Global:12cConfig.tenantId
$SubscriptionId = $Global:12cConfig.subscriptionId
$ArtifactsFeedUrl = $Global:12cConfig.artifactsFeedUrl 

# Check if essential config values were found
if ([string]::IsNullOrEmpty($KeyVaultName) -or [string]::IsNullOrEmpty($TenantId) -or [string]::IsNullOrEmpty($SubscriptionId) -or [string]::IsNullOrEmpty($ArtifactsFeedUrl)) {
    Write-Error "One or more required configuration values (KeyVaultName, TenantId, SubscriptionId, ArtifactsFeedUrl) could not be retrieved from the global configuration (expected in \\$Global:12cConfig). Ensure Initialize-12Configuration has run successfully and set them."
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
nuget push $nupkgFilePath -Source $ArtifactsFeed -ApiKey "AzureDevOps"

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

