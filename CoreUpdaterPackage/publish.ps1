# publish.ps1
# Publish script for CoreUpdaterPackage using the common Packaging module

$ArtifactsFeedName = "OrchestratorPshRepo"
$SecretName = "PAT"
$PackageName = "CoreUpdaterPackage"

# --- Path Definitions ---
$basePath = ($PSScriptRoot ? $PSScriptRoot : (Get-Location).Path)
$envConfigPath = Join-Path $basePath '..\environments\dev.json'
$commonModuleRootPath = Join-Path $basePath '..\Modules\OrchestratorCommon'
$packagingModulePath = Join-Path $basePath '..\Modules\Packaging\Packaging.psd1'
$nuspecFilePath = Join-Path $basePath 'CoreUpdaterPackage.nuspec'
$outputDirectory = Join-Path $basePath '..\Output'

# --- Module Imports & Initialization ---
try {
    if (Test-Path $commonModuleRootPath) { Import-Module $commonModuleRootPath -Force }
    Import-Module $packagingModulePath
    Initialize-12Configuration $envConfigPath
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
} catch {
    Write-Error "An error occurred during script execution: $($_.Exception.Message)"
    exit 1
}
