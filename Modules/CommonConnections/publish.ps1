# publish.ps1
# Script to publish the CommonConnectionsPackage to a NuGet feed

# --- Script Parameters & Static Configuration ---
$ArtifactsFeedName = "OrchestratorPshRepo" # Renamed for clarity
$SecretName = "PAT"   # Name of the secret in Key Vault storing the PAT
$PackageName = "CommonConnectionsPackage" # Base name of the package

# --- Path Definitions ---
$basePath = ($PSScriptRoot ? $PSScriptRoot : (Get-Location).Path) # Base path for relative calculations

$envConfigPath = Join-Path $basePath "..\..\environments\dev.json"
$configModulePsd1 = Join-Path $basePath "..\Configuration\ConfigurationPackage\ConfigurationPackage.psd1"
$azureModulePsd1 = Join-Path $basePath "..\OrchestratorAzure\OrchestratorAzure.psd1"
$commonModuleRootPath = Join-Path $basePath "..\OrchestratorCommon"
$packagingModulePath = Join-Path $basePath "..\Packaging\Packaging.psd1" # Path to the Packaging module
$nuspecFilePath = Join-Path $basePath "CommonConnectionsPackage.nuspec"
$outputDirectory = Join-Path $basePath "..\..\Output"

# --- Module Imports & Initialization ---
try {
    Import-Module $configModulePsd1
    Import-Module $azureModulePsd1
    Import-Module $packagingModulePath # Import the Packaging module
    Initialize-12Configuration $envConfigPath
    Connect-12Azure

    if (Test-Path $commonModuleRootPath) {
        Import-Module $commonModuleRootPath -Force
        Write-Host "OrchestratorCommon module imported successfully." -ForegroundColor Green
    } else {
        Write-Error "OrchestratorCommon module not found at $commonModuleRootPath. Make sure the module is installed correctly."
        exit 1
    }
} catch {
    Write-Error "Failed during module import or initialization: $($_.Exception.Message)"
    exit 1
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
    $pat = Get-NuGetPATFromKeyVault -SecretName $SecretName

    # 4. Ensure NuGet Feed is Configured
    $artifactsFeedUrl = $Global:12cConfig.artifactsFeedUrl
    if ([string]::IsNullOrEmpty($artifactsFeedUrl)) {
        Write-Error "ArtifactsFeedUrl could not be retrieved from the global configuration. Ensure Initialize-12Configuration has run successfully."
        throw "Missing ArtifactsFeedUrl from global scope."
    }
    # Remove existing NuGet source if present to avoid add error
    $nugetExePath = Join-Path ($PSScriptRoot ? $PSScriptRoot : (Get-Location).Path) '..\Packaging\nuget.exe'
    & $nugetExePath sources remove -Name $ArtifactsFeedName -NonInteractive | Out-Null
    Ensure-NuGetFeedConfigured -FeedName $ArtifactsFeedName -FeedUrl $artifactsFeedUrl -PAT $pat

    # 5. Publish Package and Cleanup
    Publish-NuGetPackageAndCleanup -PackagePath $nupkgFilePath -FeedName $ArtifactsFeedName

    Write-Host "Script completed successfully." -ForegroundColor Green

} catch {
    Write-Error "An error occurred during script execution: $($_.Exception.Message)"
    exit 1
}