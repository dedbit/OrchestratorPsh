# build.ps1
# Script to build the OrchestratorRouting package

# --- Script Parameters & Static Configuration ---
$PackageBaseName = "OrchestratorRouting"

# --- Path Definitions ---
# Robust path construction
$scriptRootPath = ($PSScriptRoot ? $PSScriptRoot : (Get-Location).Path)

$NuspecFilePath = Join-Path -Path $scriptRootPath -ChildPath "OrchestratorRouting.nuspec"
$ModuleManifestPath = Join-Path -Path $scriptRootPath -ChildPath "OrchestratorRouting\OrchestratorRouting.psd1"
$OutputDirectory = Join-Path -Path $scriptRootPath -ChildPath "..\..\Output"

# --- Module Imports ---
try {
    Import-Module "..\Packaging\Packaging.psd1" -Force # Import the Packaging module using a relative path
    Write-Host "Packaging module imported successfully." -ForegroundColor Green
} catch {
    Write-Error "Failed to import Packaging module: $($_.Exception.Message)"
    exit 1
}

# --- Main Script Execution ---
try {
    # 1. Ensure the output directory exists
    Confirm-DirectoryExists -Path $OutputDirectory

    # 2. Increment version in .nuspec and .psd1 files
    $newVersion = Set-PackageVersionIncrement -NuspecPath $NuspecFilePath -ModuleManifestPath $ModuleManifestPath
    if (-not $newVersion) {
        throw "Failed to increment package version."
    }
    Write-Host "Successfully incremented package version to $newVersion" -ForegroundColor Green

    # 3. Build the NuGet package
    Invoke-NuGetPack -NuspecPath $NuspecFilePath -OutputDirectory $OutputDirectory
    Write-Host "NuGet package build initiated." -ForegroundColor Cyan

    # 4. Delete old package versions
    Remove-OldPackageVersions -OutputDirectory $OutputDirectory -PackageBaseName $PackageBaseName -VersionToKeep $newVersion
    
    Write-Host "Build process completed successfully for version $newVersion!" -ForegroundColor Green

} catch {
    Write-Error "An error occurred during the build process: $($_.Exception.Message)"
    exit 1
}