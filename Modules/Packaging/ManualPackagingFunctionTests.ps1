# ManualPackagingFunctionTests.ps1
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

# --- Test Publish-NuGetPackageAndCleanup ---
Write-Host "\nTesting Publish-NuGetPackageAndCleanup..." -ForegroundColor Cyan

# Setup dummy nuget function in session
function global:nuget {
    param($cmd, $arg1, $arg2, $arg3, $arg4, $arg5, $arg6, $arg7, $arg8, $arg9, $arg10)
    if ($cmd -eq 'push') {
        $script:nugetPushCalled = $true
        $script:nugetPushArgs = @($cmd, $arg1, $arg2, $arg3, $arg4, $arg5, $arg6, $arg7, $arg8, $arg9, $arg10)
        $global:LASTEXITCODE = 0
    } elseif ($cmd -eq 'sources' -and $arg1 -eq 'remove') {
        $script:nugetRemoveCalled = $true
        $script:nugetRemoveArgs = @($cmd, $arg1, $arg2, $arg3, $arg4, $arg5, $arg6, $arg7, $arg8, $arg9, $arg10)
        $global:LASTEXITCODE = 0
    } else {
        $global:LASTEXITCODE = 0
    }
}

$testPkg = Join-Path $env:TEMP "ManualTestPkg.nupkg"
Set-Content -Path $testPkg -Value "dummy"
$feedName = "ManualTestFeed"
$script:nugetPushCalled = $false
$script:nugetRemoveCalled = $false

try {
    Publish-NuGetPackageAndCleanup -PackagePath $testPkg -FeedName $feedName
    $result = $script:nugetPushCalled -and $script:nugetRemoveCalled
    Write-TestResult 'Publish-NuGetPackageAndCleanup basic call' $result
} catch {
    Write-TestResult 'Publish-NuGetPackageAndCleanup basic call' $false
    Write-Host $_
}

Remove-Item $testPkg -ErrorAction SilentlyContinue

# --- Test Ensure-NuGetFeedConfigured ---
Write-Host "\nTesting Ensure-NuGetFeedConfigured..." -ForegroundColor Cyan
function global:nuget {
    param($cmd, $arg1, $arg2, $arg3, $arg4, $arg5, $arg6, $arg7, $arg8, $arg9, $arg10)
    if ($cmd -eq 'sources' -and $arg1 -eq 'list') {
        $script:nugetListCalled = $true
        $global:LASTEXITCODE = 0
        return ""
    } elseif ($cmd -eq 'sources' -and $arg1 -eq 'add') {
        $script:nugetAddCalled = $true
        $global:LASTEXITCODE = 0
    } elseif ($cmd -eq 'sources' -and $arg1 -eq 'remove') {
        $script:nugetRemoveCalled = $true
        $global:LASTEXITCODE = 0
    } else {
        $global:LASTEXITCODE = 0
    }
}

$script:nugetListCalled = $false
$script:nugetAddCalled = $false
$script:nugetRemoveCalled = $false

try {
    Ensure-NuGetFeedConfigured -FeedName "ManualTestFeed" -FeedUrl "http://dummy" -PAT "dummy"
    $result = $script:nugetListCalled -and $script:nugetAddCalled
    Write-TestResult 'Ensure-NuGetFeedConfigured basic add' $result
} catch {
    Write-TestResult 'Ensure-NuGetFeedConfigured basic add' $false
    Write-Host $_
}

# --- Test Invoke-NuGetPack ---
Write-Host "\nTesting Invoke-NuGetPack..." -ForegroundColor Cyan

# Intercept both 'nuget' and 'nuget.exe' for Invoke-NuGetPack
function global:nuget {}
function global:nuget.exe {
    param($cmd, $arg1, $arg2, $arg3, $arg4, $arg5, $arg6, $arg7, $arg8, $arg9, $arg10)
    if ($cmd -eq 'pack') {
        $script:nugetPackCalled = $true
        $script:nugetPackArgs = @($cmd, $arg1, $arg2, $arg3, $arg4, $arg5, $arg6, $arg7, $arg8, $arg9, $arg10)
        $global:LASTEXITCODE = 0
    } else {
        $global:LASTEXITCODE = 0
    }
}

$testNuspec = Join-Path $env:TEMP "ManualTest.nuspec"
$testOutDir = Join-Path $env:TEMP "ManualTestOut"
Set-Content -Path $testNuspec -Value "<package><metadata><id>t</id><version>1.0.0</version><authors>a</authors><description>d</description></metadata></package>"
if (-not (Test-Path $testOutDir)) { New-Item -ItemType Directory -Path $testOutDir | Out-Null }
$script:nugetPackCalled = $false

try {
    Invoke-NuGetPack -NuspecPath $testNuspec -OutputDirectory $testOutDir
    $result = $script:nugetPackCalled
    Write-TestResult 'Invoke-NuGetPack basic call' $result
} catch {
    Write-TestResult 'Invoke-NuGetPack basic call' $false
    Write-Host $_
}

Remove-Item $testNuspec -ErrorAction SilentlyContinue
Remove-Item $testOutDir -Recurse -ErrorAction SilentlyContinue

Write-Host "\nManual tests complete." -ForegroundColor Cyan

# --- Test Get-PackageVersionFromNuspec ---
Write-Host "\nTesting Get-PackageVersionFromNuspec..." -ForegroundColor Cyan
$testNuspec = Join-Path $env:TEMP "ManualTestVer.nuspec"
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
$testDir = Join-Path $env:TEMP "ManualTestDir"
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
$testNuspec = Join-Path $env:TEMP "ManualTestInc.nuspec"
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
$testOutDir = Join-Path $env:TEMP "ManualTestOldPkg"
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
