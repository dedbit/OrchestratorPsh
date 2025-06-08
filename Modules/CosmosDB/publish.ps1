# publish.ps1
# Script to publish the CosmosDB module using the common Packaging module

$ArtifactsFeedName = "OrchestratorPshRepo"
$SecretName = "PAT"
$PackageName = "CosmosDBPackage"

# --- Path Definitions ---
$basePath = ($PSScriptRoot ? $PSScriptRoot : (Get-Location).Path)
$envConfigPath = Join-Path $basePath "..\..\environments\dev.json"
$configModulePsd1 = Join-Path $basePath "..\Configuration\ConfigurationPackage\ConfigurationPackage.psd1"
$azureModulePsd1 = Join-Path $basePath "..\OrchestratorAzure\OrchestratorAzure.psd1"
$commonModuleRootPath = Join-Path $basePath "..\OrchestratorCommon"
$packagingModulePath = Join-Path $basePath "..\Packaging\Packaging.psd1"
$nuspecFilePath = Join-Path $basePath "CosmosDBPackage.nuspec"
$outputDirectory = Join-Path $basePath "..\..\Output"

# --- Module Imports & Initialization ---
try {
    Import-Module $configModulePsd1
    Import-Module $azureModulePsd1
    Import-Module $packagingModulePath
    Initialize-12Configuration $envConfigPath
    Connect-12Azure

    if (Test-Path $commonModuleRootPath) {
        Import-Module $commonModuleRootPath -Force
    }
} catch {
    Write-Error "Failed during module import or initialization: $($_.Exception.Message)"
    exit 1
}

# --- Main Script Execution ---
try {
    $packageVersion = Get-PackageVersionFromNuspec -NuspecPath $nuspecFilePath
    $nupkgFilePath = Join-Path -Path $outputDirectory -ChildPath "$PackageName.$packageVersion.nupkg"
    Write-Host "Full package path: $nupkgFilePath" -ForegroundColor Cyan
    if (-not (Test-Path $nupkgFilePath)) { throw "Package file not found: $nupkgFilePath" }

    $pat = Get-NuGetPATFromKeyVault -SecretName $SecretName
    $artifactsFeedUrl = $Global:12cConfig.artifactsFeedUrl
    if ([string]::IsNullOrEmpty($artifactsFeedUrl)) { throw "Missing ArtifactsFeedUrl from global scope." }
    Ensure-NuGetFeedConfigured -FeedName $ArtifactsFeedName -FeedUrl $artifactsFeedUrl -PAT $pat

    Publish-NuGetPackageAndCleanup -PackagePath $nupkgFilePath -FeedName $ArtifactsFeedName

    Write-Host "Script completed successfully." -ForegroundColor Green
} catch {
    Write-Error "An error occurred during script execution: $($_.Exception.Message)"
    exit 1
}
