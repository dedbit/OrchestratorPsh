# build.ps1
# Script to build the messaging package

# Parameters
param (
    [string]$OutputPath = "..\Output",
    [string]$Version = "1.0.0",
    [switch]$Force
)

# Get the directory where this script is located
$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
$modulePath = Join-Path -Path $scriptPath -ChildPath "Module"

# Create output directory if it doesn't exist
if (-not (Test-Path $OutputPath)) {
    New-Item -Path $OutputPath -ItemType Directory -Force | Out-Null
    Write-Host "Created output directory: $OutputPath" -ForegroundColor Green
}

# Package name
$packageName = "MessagingPackage.$Version.nupkg"
$packageFullPath = Join-Path -Path $OutputPath -ChildPath $packageName

# Check if package already exists
if ((Test-Path $packageFullPath) -and -not $Force) {
    Write-Warning "Package already exists at $packageFullPath. Use -Force to overwrite."
    exit 0
}

# Building package logic will go here
Write-Host "Building messaging package version $Version..." -ForegroundColor Cyan

# TODO: Add actual build logic

# For now, just create a placeholder nuspec file
$nuspecContent = @"
<?xml version="1.0" encoding="utf-8"?>
<package xmlns="http://schemas.microsoft.com/packaging/2010/07/nuspec.xsd">
    <metadata>
        <id>MessagingPackage</id>
        <version>$Version</version>
        <authors>OrchestratorPsh</authors>
        <description>Messaging package for OrchestratorPsh</description>
    </metadata>
    <files>
        <file src="Module\**" target="Module" />
    </files>
</package>
"@

$nuspecPath = Join-Path -Path $scriptPath -ChildPath "MessagingPackage.nuspec"
Set-Content -Path $nuspecPath -Value $nuspecContent -Force

# Copy module files to a temp directory for packaging (would be used in actual implementation)
# For now, just report the files found
$moduleFiles = Get-ChildItem -Path $modulePath -Recurse
Write-Host "Found $($moduleFiles.Count) files in module directory" -ForegroundColor Yellow

Write-Host "Build process completed!" -ForegroundColor Green
Write-Host "Package would be created at: $packageFullPath"

# Placeholder for actual nuget pack command
# nuget pack "$nuspecPath" -OutputDirectory "$OutputPath" -Version "$Version" -NoPackageAnalysis
