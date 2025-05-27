# publish.ps1
# Script to publish the messaging package to a NuGet feed

# Todo:
# If artifacts feed already exists it fails. 

# Import the Az module to interact with Azure services
# Import-Module Az

#region Helper Functions

function Get-PackageVersionFromNuspec {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$NuspecPath
    )
    Write-Host "Reading package version from: $NuspecPath" -ForegroundColor Cyan
    if (-not (Test-Path $NuspecPath)) {
        Write-Error "Nuspec file not found at $NuspecPath. Please build the package first or check the path."
        throw "Nuspec file not found: $NuspecPath"
    }
    $nuspecContent = Get-Content $NuspecPath -Raw
    if ($nuspecContent -match '<version>([0-9]+)\.([0-9]+)\.([0-9]+)</version>') {
        $major = $matches[1]
        $minor = $matches[2]
        $patch = $matches[3]
        $versionValue = "$major.$minor.$patch"
        Write-Host "Package version from nuspec: $versionValue" -ForegroundColor Cyan
        return $versionValue
    } else {
        Write-Error "Failed to find version in nuspec file: $NuspecPath"
        throw "Failed to find version in nuspec file: $NuspecPath"
    }
}

function Get-NuGetPATFromKeyVault {
    [CmdletBinding()]
    param(
        # SecretName is hardcoded for this script's specific purpose but could be a parameter
    )
    # Access configuration values from the globally initialized configuration
    # Initialize-12Configuration stores config in $Global:12cConfig
    $kvName = $Global:12cConfig.keyVaultName
    $tenId = $Global:12cConfig.tenantId
    $subId = $Global:12cConfig.subscriptionId
    # $SecretName is a script-level variable defined in 'Script Parameters & Static Configuration'

    # Check if essential config values were found
    if ([string]::IsNullOrEmpty($kvName) -or [string]::IsNullOrEmpty($tenId) -or [string]::IsNullOrEmpty($subId)) {
        Write-Error "One or more required configuration values (KeyVaultName, TenantId, SubscriptionId) could not be retrieved from the global configuration (expected in \$Global:12cConfig). Ensure Initialize-12Configuration has run successfully and set them."
        throw "Missing KeyVault configuration from global scope."
    }

    Write-Host "Retrieving PAT from Key Vault: $kvName (Secret: $SecretName)" -ForegroundColor Cyan
    $pat = Get-PATFromKeyVault -KeyVaultName $kvName -SecretName $Script:SecretName -TenantId $tenId -SubscriptionId $subId

    if ([string]::IsNullOrEmpty($pat)) {
        Write-Error "Failed to retrieve Personal Access Token from Key Vault. Aborting."
        throw "Failed to retrieve PAT from Key Vault."
    }
    return $pat
}

function Publish-NuGetPackageAndCleanup {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$PackagePath,

        [Parameter(Mandatory=$true)]
        [string]$FeedName
    )
    Write-Host "Pushing package '$PackagePath' to feed '$FeedName'..." -ForegroundColor Cyan
    nuget push $PackagePath -Source $FeedName -ApiKey "AzureDevOps" # ApiKey is often a placeholder for Azure Artifacts

    if ($LASTEXITCODE -ne 0) {
        Write-Error "Failed to publish NuGet package. NuGet exited with code $LASTEXITCODE."
        # Attempt to clean up the NuGet source even if push failed, but don't let this mask the original error
        Write-Host "Attempting to clean up NuGet source '$FeedName' after failed push..." -ForegroundColor Yellow
        try {
            nuget sources remove -Name $FeedName
        } catch {
            Write-Warning "Failed to remove NuGet source '$FeedName' during cleanup after failed push: $($_.Exception.Message)"
        }
        throw "NuGet push failed with exit code $LASTEXITCODE."
    } else {
        Write-Host "Package published successfully to '$FeedName'!" -ForegroundColor Green
    }

    # Clean up the NuGet source to remove sensitive information
    Write-Host "Cleaning up NuGet source '$FeedName' after successful push..." -ForegroundColor Cyan
    try {
        nuget sources remove -Name $FeedName
        if ($LASTEXITCODE -ne 0) {
            Write-Warning "Could not remove NuGet source '$FeedName' after successful push. Exit code: $LASTEXITCODE"
        }
    } catch {
        Write-Warning "An error occurred while trying to remove NuGet source '$FeedName' after successful push: $($_.Exception.Message)"
    }
}

# Function to ensure NuGet feed is configured (existing function, slightly adapted if needed)
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
        if ($sourceExistsOutput -is [array]) {
            # Corrected line: Use double quotes for the newline character `n within the string for -join
            if ($sourceExistsOutput -join "`n" -match [regex]::Escape($FeedName)) {
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
        throw "Failed to add NuGet source '$FeedName'."
    }
    Write-Host "NuGet source '$FeedName' configured." -ForegroundColor Green
}

#endregion Helper Functions

# --- Script Parameters & Static Configuration ---
$ArtifactsFeedName = "OrchestratorPshRepo" # Renamed for clarity (was $ArtifactsFeed)
$SecretName = "PAT"   # Name of the secret in Key Vault storing the PAT
$PackageName = "ConfigurationPackage" # Base name of the package

# --- Path Definitions ---
$basePath = ($PSScriptRoot ? $PSScriptRoot : (Get-Location).Path) # Base path for relative calculations

$envConfigPath = Join-Path $basePath "..\..\environments\dev.json"
$configModulePsd1 = Join-Path $basePath "ConfigurationPackage\ConfigurationPackage.psd1"
$azureModulePsd1 = Join-Path $basePath "..\OrchestratorAzure\OrchestratorAzure.psd1"
$commonModuleRootPath = Join-Path $basePath "..\OrchestratorCommon"
$nuspecFilePath = Join-Path $basePath "ConfigurationPackage.nuspec"
$outputDirectory = Join-Path $basePath "..\..\Output"

# --- Module Imports & Initialization ---
try {
    Import-Module $configModulePsd1
    Import-Module $azureModulePsd1
    Initialize-12Configuration $envConfigPath # Uses $envConfigPath
    Connect-12Azure

    if (Test-Path $commonModuleRootPath) {
        Import-Module $commonModuleRootPath -Force
        Write-Host "OrchestratorCommon module imported successfully." -ForegroundColor Green
    } else {
        Write-Error "OrchestratorCommon module not found at $commonModuleRootPath. Make sure the module is installed correctly."
        exit 1 # Or throw
    }
} catch {
    Write-Error "Failed during module import or initialization: $($_.Exception.Message)"
    exit 1 # Stop script if essential setup fails
}

# --- Main Script Execution ---
try {
    # 1. Get Package Version
    $packageVersion = Get-PackageVersionFromNuspec -NuspecPath $nuspecFilePath

    # 2. Construct Final Package Path
    $nupkgFilePath = Join-Path -Path $outputDirectory -ChildPath ("$PackageName.$packageVersion.nupkg")
    Write-Host "Full package path: $nupkgFilePath" -ForegroundColor Cyan
    if (-not (Test-Path $nupkgFilePath)) {
        Write-Error "Package file not found at $nupkgFilePath. Please build the package first."
        throw "Package file not found: $nupkgFilePath"
    }

    # 3. Retrieve PAT
    $personalAccessToken = Get-NuGetPATFromKeyVault
    $artifactsFeedUrlFromConfig = $Global:12cConfig.artifactsFeedUrl # Get this after PAT retrieval, as PAT func checks global config
    if ([string]::IsNullOrEmpty($artifactsFeedUrlFromConfig)) {
        Write-Error "ArtifactsFeedUrl could not be retrieved from \$Global:12cConfig.artifactsFeedUrl"
        throw "Missing ArtifactsFeedUrl from global config"
    }

    # 4. Ensure NuGet Feed is Configured
    Ensure-NuGetFeedConfigured -FeedName $ArtifactsFeedName -FeedUrl $artifactsFeedUrlFromConfig -PAT $personalAccessToken

    # 5. Publish Package and Cleanup
    Publish-NuGetPackageAndCleanup -PackagePath $nupkgFilePath -FeedName $ArtifactsFeedName

    Write-Host "All operations completed successfully!" -ForegroundColor Green

} catch {
    Write-Error "An error occurred during script execution: $($_.Exception.Message)"
    # Consider if any additional specific cleanup is needed here, though functions should handle their own.
    exit 1
}

