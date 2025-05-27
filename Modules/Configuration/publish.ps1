# publish.ps1
# Script to publish the messaging package to a NuGet feed

# Todo:
# If artifacts feed already exists it fails. 

# Import the Az module to interact with Azure services
# Import-Module Az

#region Helper Functions
# Helper functions have been moved to the 'Packaging' module.
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
$packagingModulePath = Join-Path $basePath "..\Packaging\Packaging.psd1" # Path to the new Packaging module
$nuspecFilePath = Join-Path $basePath "ConfigurationPackage.nuspec"
$outputDirectory = Join-Path $basePath "..\..\Output"

# --- Module Imports & Initialization ---
try {
    Import-Module $configModulePsd1
    Import-Module $azureModulePsd1
    Import-Module $packagingModulePath # Import the new Packaging module
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

    # 3. Retrieve PAT from Key Vault
    # The Get-NuGetPATFromKeyVault function now takes SecretName as a parameter
    $pat = Get-NuGetPATFromKeyVault -SecretName $SecretName

    # 4. Ensure NuGet Feed is Configured
    # Access the ArtifactsFeedUrl from the global configuration
    $artifactsFeedUrl = $Global:12cConfig.artifactsFeedUrl
    if ([string]::IsNullOrEmpty($artifactsFeedUrl)) {
        Write-Error "ArtifactsFeedUrl could not be retrieved from the global configuration (expected in \$Global:12cConfig). Ensure Initialize-12Configuration has run successfully and set it."
        throw "Missing ArtifactsFeedUrl from global scope."
    }
    Ensure-NuGetFeedConfigured -FeedName $ArtifactsFeedName -FeedUrl $artifactsFeedUrl -PAT $pat

    # 5. Publish Package and Cleanup
    Publish-NuGetPackageAndCleanup -PackagePath $nupkgFilePath -FeedName $ArtifactsFeedName

    Write-Host "Script completed successfully." -ForegroundColor Green

} catch {
    Write-Error "An error occurred during script execution: $($_.Exception.Message)"
    # Additional cleanup or error handling specific to the main script block can go here
    # For example, ensuring the NuGet source is removed if an error happens after it was added
    # but before the publish command, or if publish fails.
    # The Publish-NuGetPackageAndCleanup function already tries to clean up the source.
    exit 1
}

