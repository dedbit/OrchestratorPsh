# publish.ps1
# Script to publish the Packaging module NuGet package

# --- Script Parameters & Static Configuration ---
$ArtifactsFeedName = "OrchestratorPshRepo" # Use same feed name as Configuration module
$SecretName = "PAT"   # Name of the secret in Key Vault storing the PAT (same as Configuration module)
$PackageName = "Packaging" # Base name of the package

# --- Path Definitions ---
$basePath = ($PSScriptRoot ? $PSScriptRoot : (Get-Location).Path) # Base path for relative calculations

$envConfigPath = Join-Path $basePath "..\..\environments\dev.json"
$configModulePsd1 = Join-Path $basePath "..\Configuration\ConfigurationPackage\ConfigurationPackage.psd1"
$azureModulePsd1 = Join-Path $basePath "..\OrchestratorAzure\OrchestratorAzure.psd1"
$packagingModulePath = Join-Path $basePath "Packaging.psd1" # Path to the Packaging module
$nuspecFilePath = Join-Path $basePath "Packaging.nuspec"
$outputDirectory = Join-Path $basePath "..\..\Output"

# --- Module Imports & Initialization ---
try {
    Import-Module $configModulePsd1
    Import-Module $azureModulePsd1
    Import-Module $packagingModulePath # Import the Packaging module
    Initialize-12Configuration $envConfigPath # Uses $envConfigPath
    Connect-12Azure

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
    
    # Use the self-contained nuget.exe for this module
    $nugetExePath = Join-Path $basePath "nuget.exe"
    Ensure-NuGetFeedConfigured -FeedName $ArtifactsFeedName -FeedUrl $artifactsFeedUrl -PAT $pat -NuGetExePath $nugetExePath

    # 5. Publish Package and Cleanup
    Publish-NuGetPackageAndCleanup -PackagePath $nupkgFilePath -FeedName $ArtifactsFeedName -NuGetExePath $nugetExePath

    Write-Host "Script completed successfully." -ForegroundColor Green

} catch {
    Write-Error "An error occurred during script execution: $($_.Exception.Message)"
    # Additional cleanup or error handling specific to the main script block can go here
    # For example, ensuring the NuGet source is removed if an error happens after it was added
    # but before the publish command, or if publish fails.
    # The Publish-NuGetPackageAndCleanup function already tries to clean up the source.
    exit 1
}