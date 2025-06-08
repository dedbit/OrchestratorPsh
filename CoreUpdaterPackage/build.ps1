# build.ps1
# Build script for the CoreUpdaterPackage using the common Packaging module

$PackageBaseName = "CoreUpdaterPackage"

# --- Path Definitions ---
$scriptRootPath = ($PSScriptRoot ? $PSScriptRoot : (Get-Location).Path)
$NuspecFilePath = Join-Path -Path $scriptRootPath -ChildPath "CoreUpdaterPackage.nuspec"
$OutputDirectory = Join-Path -Path $scriptRootPath -ChildPath "..\Output"
$NuGetExePath = Join-Path -Path $scriptRootPath -ChildPath "..\Tools\nuget.exe"

# --- Module Import ---
try {
    Import-Module "..\Modules\Packaging\Packaging.psd1" -Force
    Write-Host "Packaging module imported successfully." -ForegroundColor Green
} catch {
    Write-Error "Failed to import Packaging module: $($_.Exception.Message)"
    exit 1
}

# --- Main Script Execution ---
try {
    Confirm-DirectoryExists -Path $OutputDirectory

    $newVersion = Set-PackageVersionIncrement -NuspecPath $NuspecFilePath
    if (-not $newVersion) { throw "Failed to increment package version." }
    Write-Host "Successfully incremented package version to $newVersion" -ForegroundColor Cyan

    Invoke-NuGetPack -NuspecPath $NuspecFilePath -OutputDirectory $OutputDirectory -NuGetExePath $NuGetExePath

    Remove-OldPackageVersions -OutputDirectory $OutputDirectory -PackageBaseName $PackageBaseName -VersionToKeep $newVersion

    Write-Host "Build process completed successfully for version $newVersion!" -ForegroundColor Green
} catch {
    Write-Error "An error occurred during the build process: $($_.Exception.Message)"
    exit 1
}