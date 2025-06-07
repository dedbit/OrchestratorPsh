# test-manual-packaging-functions.ps1
# Simple PowerShell tests for Packaging.psm1 functions that use nuget (no Pester required)

Import-Module (Join-Path $PSScriptRoot 'Packaging.psm1') -Force

function Write-TestResult {
    param($TestName, $Result)
    if ($Result) {
        Write-Host "PASS: $TestName" -ForegroundColor Green
    } else {
        Write-Host "FAIL: $TestName" -ForegroundColor Red
    }
}

# Create a mock nuget.exe script for testing
$tempDir = if ($env:TEMP) { $env:TEMP } elseif ($env:TMPDIR) { $env:TMPDIR } else { "/tmp" }

# Create test tracking files
$testTrackingDir = Join-Path $tempDir "nuget-test-tracking"
if (Test-Path $testTrackingDir) { Remove-Item $testTrackingDir -Recurse -Force }
New-Item -ItemType Directory -Path $testTrackingDir | Out-Null

# Create PowerShell mock script
$mockNugetPS1Path = Join-Path $tempDir "mock-nuget.ps1"
$mockNugetContent = @"
param(`$Command, `$arg1, `$arg2, `$arg3, `$arg4, `$arg5, `$arg6, `$arg7, `$arg8, `$arg9, `$arg10)

`$trackingDir = "$testTrackingDir"
`$args = @(`$Command, `$arg1, `$arg2, `$arg3, `$arg4, `$arg5, `$arg6, `$arg7, `$arg8, `$arg9, `$arg10) | Where-Object { `$_ -ne `$null }

# Track calls using files
if (`$Command -eq 'push') {
    Set-Content -Path (Join-Path `$trackingDir "push-called") -Value (`$args -join ' ')
} elseif (`$Command -eq 'sources' -and `$arg1 -eq 'remove') {
    Set-Content -Path (Join-Path `$trackingDir "remove-called") -Value (`$args -join ' ')
} elseif (`$Command -eq 'sources' -and `$arg1 -eq 'list') {
    Set-Content -Path (Join-Path `$trackingDir "list-called") -Value (`$args -join ' ')
    # Return empty string for sources list
    Write-Output ""
} elseif (`$Command -eq 'sources' -and `$arg1 -eq 'add') {
    Set-Content -Path (Join-Path `$trackingDir "add-called") -Value (`$args -join ' ')
} elseif (`$Command -eq 'pack') {
    Set-Content -Path (Join-Path `$trackingDir "pack-called") -Value (`$args -join ' ')
}

exit 0
"@
Set-Content -Path $mockNugetPS1Path -Value $mockNugetContent

# Create platform-specific executable wrapper script
$isWindowsPlatform = ($env:OS -eq "Windows_NT") -or ($PSVersionTable.PSEdition -eq "Desktop") -or ($PSVersionTable.Platform -eq "Win32NT")

if ($isWindowsPlatform) {
    # Create Windows batch file
    $mockNugetPath = Join-Path $tempDir "mock-nuget.bat"
    $wrapperContent = @"
@echo off
pwsh -File "$mockNugetPS1Path" %*
"@
    Set-Content -Path $mockNugetPath -Value $wrapperContent
} else {
    # Create Unix shell script
    $mockNugetPath = Join-Path $tempDir "mock-nuget"
    $wrapperContent = @"
#!/bin/bash
pwsh -File "$mockNugetPS1Path" `$@
"@
    Set-Content -Path $mockNugetPath -Value $wrapperContent
    # Make the wrapper executable on Unix-like systems
    chmod +x $mockNugetPath 2>/dev/null
}

# --- Test Publish-NuGetPackageAndCleanup ---
Write-Host "\nTesting Publish-NuGetPackageAndCleanup..." -ForegroundColor Cyan

$testPkg = Join-Path $tempDir "ManualTestPkg.nupkg"
Set-Content -Path $testPkg -Value "dummy"
$feedName = "ManualTestFeed"

try {
    Publish-NuGetPackageAndCleanup -PackagePath $testPkg -FeedName $feedName -NuGetExePath $mockNugetPath
    $pushCalled = Test-Path (Join-Path $testTrackingDir "push-called")
    $removeCalled = Test-Path (Join-Path $testTrackingDir "remove-called")
    $result = $pushCalled -and $removeCalled
    Write-TestResult 'Publish-NuGetPackageAndCleanup basic call' $result
} catch {
    Write-TestResult 'Publish-NuGetPackageAndCleanup basic call' $false
    Write-Host $_
}

Remove-Item $testPkg -ErrorAction SilentlyContinue

# --- Test Ensure-NuGetFeedConfigured ---
Write-Host "\nTesting Ensure-NuGetFeedConfigured..." -ForegroundColor Cyan

# Clear previous tracking files
Get-ChildItem -Path $testTrackingDir -Filter "*-called" | Remove-Item -Force

try {
    Ensure-NuGetFeedConfigured -FeedName "ManualTestFeed" -FeedUrl "https://dummy" -PAT "dummy" -NuGetExePath $mockNugetPath
    $listCalled = Test-Path (Join-Path $testTrackingDir "list-called")
    $addCalled = Test-Path (Join-Path $testTrackingDir "add-called")
    $result = $listCalled -and $addCalled
    Write-TestResult 'Ensure-NuGetFeedConfigured basic add' $result
} catch {
    Write-TestResult 'Ensure-NuGetFeedConfigured basic add' $false
    Write-Host $_
}

# --- Test Invoke-NuGetPack ---
Write-Host "\nTesting Invoke-NuGetPack..." -ForegroundColor Cyan

$testNuspec = Join-Path $tempDir "ManualTest.nuspec"
$testOutDir = Join-Path $tempDir "ManualTestOut"
Set-Content -Path $testNuspec -Value "<package><metadata><id>t</id><version>1.0.0</version><authors>a</authors><description>d</description></metadata></package>"
if (-not (Test-Path $testOutDir)) { New-Item -ItemType Directory -Path $testOutDir | Out-Null }

# Clear previous tracking files
Get-ChildItem -Path $testTrackingDir -Filter "*-called" | Remove-Item -Force

try {
    Invoke-NuGetPack -NuspecPath $testNuspec -OutputDirectory $testOutDir -NuGetExePath $mockNugetPath
    $packCalled = Test-Path (Join-Path $testTrackingDir "pack-called")
    Write-TestResult 'Invoke-NuGetPack basic call' $packCalled
} catch {
    Write-TestResult 'Invoke-NuGetPack basic call' $false
    Write-Host $_
}

Remove-Item $testNuspec -ErrorAction SilentlyContinue
Remove-Item $testOutDir -Recurse -ErrorAction SilentlyContinue

Write-Host "\nManual tests complete." -ForegroundColor Cyan

# Clean up mock scripts and tracking
Remove-Item $mockNugetPath -ErrorAction SilentlyContinue
Remove-Item $mockNugetPS1Path -ErrorAction SilentlyContinue
Remove-Item $testTrackingDir -Recurse -ErrorAction SilentlyContinue

# --- Test Get-PackageVersionFromNuspec ---
Write-Host "\nTesting Get-PackageVersionFromNuspec..." -ForegroundColor Cyan
$testNuspec = Join-Path $tempDir "ManualTestVer.nuspec"
Set-Content -Path $testNuspec -Value "<package><metadata><id>t</id><version>2.3.4</version><authors>a</authors><description>d</description></metadata></package>"
$version = $null
try {
    $version = Get-PackageVersionFromNuspec -NuspecPath $testNuspec
    $result = ($version -eq '2.3.4')
    Write-TestResult 'Get-PackageVersionFromNuspec basic' $result
} catch {
    Write-TestResult 'Get-PackageVersionFromNuspec basic' $false
    Write-Host $_
}
Remove-Item $testNuspec -ErrorAction SilentlyContinue

# --- Test Confirm-DirectoryExists ---
Write-Host "\nTesting Confirm-DirectoryExists..." -ForegroundColor Cyan
$testDir = Join-Path $tempDir "ManualTestDir"
if (Test-Path $testDir) { Remove-Item $testDir -Recurse -Force }
try {
    Confirm-DirectoryExists -Path $testDir
    $result = Test-Path $testDir
    Write-TestResult 'Confirm-DirectoryExists creates dir' $result
} catch {
    Write-TestResult 'Confirm-DirectoryExists creates dir' $false
    Write-Host $_
}
Remove-Item $testDir -Recurse -ErrorAction SilentlyContinue

# --- Test Set-PackageVersionIncrement ---
Write-Host "\nTesting Set-PackageVersionIncrement..." -ForegroundColor Cyan
$testNuspec = Join-Path $tempDir "ManualTestInc.nuspec"
Set-Content -Path $testNuspec -Value "<package><metadata><id>t</id><version>1.2.3</version><authors>a</authors><description>d</description></metadata></package>"
$newVer = $null
try {
    $newVer = Set-PackageVersionIncrement -NuspecPath $testNuspec
    $result = ($newVer -eq '1.2.4')
    Write-TestResult 'Set-PackageVersionIncrement basic' $result
} catch {
    Write-TestResult 'Set-PackageVersionIncrement basic' $false
    Write-Host $_
}
Remove-Item $testNuspec -ErrorAction SilentlyContinue

# --- Test Remove-OldPackageVersions ---
Write-Host "\nTesting Remove-OldPackageVersions..." -ForegroundColor Cyan
$testOutDir = Join-Path $tempDir "ManualTestOldPkg"
if (Test-Path $testOutDir) { Remove-Item $testOutDir -Recurse -Force }
New-Item -ItemType Directory -Path $testOutDir | Out-Null
$baseName = "TestPkg"
$keepVer = "1.0.2"
$files = @("$baseName.1.0.1.nupkg", "$baseName.1.0.2.nupkg", "$baseName.1.0.3.nupkg")
foreach ($f in $files) { Set-Content -Path (Join-Path $testOutDir $f) -Value "dummy" }
try {
    Remove-OldPackageVersions -OutputDirectory $testOutDir -PackageBaseName $baseName -VersionToKeep $keepVer
    $remaining = @(Get-ChildItem -Path $testOutDir -Filter "*.nupkg" | Select-Object -ExpandProperty Name)
    Write-Host "Remaining files after Remove-OldPackageVersions: $($remaining -join ', ')" -ForegroundColor Yellow
    $result = ($remaining.Count -eq 1 -and $remaining[0] -eq "$baseName.$keepVer.nupkg")
    Write-TestResult 'Remove-OldPackageVersions keeps only specified version' $result
} catch {
    Write-TestResult 'Remove-OldPackageVersions keeps only specified version' $false
    Write-Host $_
}
Remove-Item $testOutDir -Recurse -ErrorAction SilentlyContinue
