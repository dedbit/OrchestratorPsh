# Define variables
$packagePath = "CoreUpdaterPackage.nuspec"
$outputDirectory = "..\Output"
$nugetPath = "..\Tools\nuget.exe"

# Ensure the output directory exists
if (-Not (Test-Path -Path $outputDirectory)) {
    New-Item -ItemType Directory -Path $outputDirectory | Out-Null
}

# Build the NuGet package
Write-Host "Building NuGet package..."
& $nugetPath pack $packagePath -OutputDirectory $outputDirectory

if ($LASTEXITCODE -eq 0) {
    Write-Host "NuGet package built successfully."
} else {
    Write-Host "Failed to build NuGet package." -ForegroundColor Red
    exit $LASTEXITCODE
}