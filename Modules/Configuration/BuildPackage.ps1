# build.ps1
# Script to build the messaging package

# Define variables
$packageBaseName = "ConfigurationPackage"
$packagePath = "ConfigurationPackage.nuspec"
$outputDirectory = "..\..\Output"
$nugetPath = "..\..\Tools\nuget.exe"

# Ensure the output directory exists
if (-Not (Test-Path -Path $outputDirectory)) {
    New-Item -ItemType Directory -Path $outputDirectory | Out-Null
    Write-Host "Created output directory: $outputDirectory" -ForegroundColor Green
}

# Automatically increment the version number in the .nuspec file
$nuspecContent = Get-Content $packagePath -Raw
if ($nuspecContent -match '<version>([0-9]+)\.([0-9]+)\.([0-9]+)</version>') {
    $major = [int]$matches[1]
    $minor = [int]$matches[2]
    $patch = [int]$matches[3] + 1
    $newVersion = "$major.$minor.$patch"
    
    # Update nuspec file
    $nuspecContent = $nuspecContent -replace '<version>[0-9]+\.[0-9]+\.[0-9]+</version>', "<version>$newVersion</version>"
    Set-Content $packagePath $nuspecContent
    Write-Host "Nuspec version updated to $newVersion" -ForegroundColor Cyan
    
    # Update module manifest
    $modulePath = Join-Path -Path (Get-Location) -ChildPath "Module\MessagingModule.psd1"
    if (Test-Path $modulePath) {
        $moduleContent = Get-Content $modulePath -Raw
        $moduleContent = $moduleContent -replace "ModuleVersion = '[0-9]+\.[0-9]+\.[0-9]+'", "ModuleVersion = '$newVersion'"
        Set-Content $modulePath $moduleContent
        Write-Host "Module manifest version updated to $newVersion" -ForegroundColor Cyan
    } else {
        Write-Host "Module manifest file not found at $modulePath" -ForegroundColor Yellow
    }
} else {
    Write-Host "Failed to find version in nuspec file." -ForegroundColor Red
    exit 1
}

# Build the NuGet package
Write-Host "Building NuGet package..." -ForegroundColor Cyan
& $nugetPath pack $packagePath -OutputDirectory $outputDirectory

# Delete the old version if the new version is built successfully
if ($LASTEXITCODE -eq 0) {
    Write-Host "NuGet package built successfully." -ForegroundColor Green

    # Get the list of old package files
    $oldPackages = Get-ChildItem -Path $outputDirectory -Filter "$($packageBaseName).*.nupkg" | Where-Object { $_.Name -ne "$($packageBaseName).$major.$minor.$patch.nupkg" }

    foreach ($oldPackage in $oldPackages) {
        Write-Host "Deleting old package: $($oldPackage.Name)" -ForegroundColor Yellow
        Remove-Item -Path $oldPackage.FullName -Force
    }
    
    Write-Host "Build process completed!" -ForegroundColor Green
} else {
    Write-Host "Failed to build NuGet package." -ForegroundColor Red
    exit $LASTEXITCODE
}
