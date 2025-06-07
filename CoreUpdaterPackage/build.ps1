# Define paths at top of script
$scriptRoot = $PSScriptRoot ? $PSScriptRoot : (Get-Location).Path
$packagePath = Join-Path $scriptRoot 'CoreUpdaterPackage.nuspec'
$outputDirectory = Join-Path $scriptRoot '..\Output'
$nugetPath = Join-Path $scriptRoot '..\Tools\nuget.exe'

# Ensure the output directory exists
if (-Not (Test-Path -Path $outputDirectory)) {
    New-Item -ItemType Directory -Path $outputDirectory | Out-Null
}

# Automatically increment the version number in the .nuspec file
$nuspecContent = Get-Content $packagePath -Raw
if ($nuspecContent -match '<version>([0-9]+)\.([0-9]+)\.([0-9]+)</version>') {
    $major = [int]$matches[1]
    $minor = [int]$matches[2]
    $patch = [int]$matches[3] + 1
    $newVersion = "<version>$major.$minor.$patch</version>"
    $nuspecContent = $nuspecContent -replace '<version>[0-9]+\.[0-9]+\.[0-9]+</version>', $newVersion
    Set-Content $packagePath $nuspecContent
    Write-Host "Version updated to $major.$minor.$patch"
} else {
    Write-Host "Failed to find version in nuspec file." -ForegroundColor Red
    exit 1
}

# Build the NuGet package
Write-Host "Building NuGet package..."
& $nugetPath pack $packagePath -OutputDirectory $outputDirectory

# Delete the old version if the new version is built successfully
if ($LASTEXITCODE -eq 0) {
    Write-Host "NuGet package built successfully."

    # Get the list of old package files
    $oldPackages = Get-ChildItem -Path $outputDirectory -Filter "CoreUpdaterPackage.*.nupkg" | Where-Object { $_.Name -ne "CoreUpdaterPackage.$major.$minor.$patch.nupkg" }

    foreach ($oldPackage in $oldPackages) {
        Write-Host "Deleting old package: $($oldPackage.Name)"
        Remove-Item -Path $oldPackage.FullName -Force
    }
} else {
    Write-Host "Failed to build NuGet package." -ForegroundColor Red
    exit $LASTEXITCODE
}