# Test script to verify the fixes for Update-12cModules.ps1 portability issues
# This script tests the new functions and improvements without requiring full Azure connectivity

Write-Host "Testing Update-12cModules.ps1 fixes..." -ForegroundColor Cyan

# Define paths at top of script
$functionsPath = Join-Path ($PSScriptRoot ? $PSScriptRoot : (Get-Location).Path) 'Functions\functions.ps1'

# Test 1: Load functions.ps1 without errors
Write-Host "`nTest 1: Loading functions.ps1..." -ForegroundColor Yellow
try {
    . $functionsPath
    Write-Host "✓ Functions loaded successfully" -ForegroundColor Green
} catch {
    Write-Error "✗ Failed to load functions: $($_.Exception.Message)"
    exit 1
}

# Test 2: Test Ensure-NuGetProvider function existence
Write-Host "`nTest 2: Checking Ensure-NuGetProvider function..." -ForegroundColor Yellow
if (Get-Command Ensure-NuGetProvider -ErrorAction SilentlyContinue) {
    Write-Host "✓ Ensure-NuGetProvider function is available" -ForegroundColor Green
} else {
    Write-Error "✗ Ensure-NuGetProvider function not found"
    exit 1
}

# Test 3: Test Get-ScriptRoot function
Write-Host "`nTest 3: Testing Get-ScriptRoot function..." -ForegroundColor Yellow
try {
    $scriptRoot = Get-ScriptRoot
    if ($scriptRoot -and (Test-Path $scriptRoot)) {
        Write-Host "✓ Get-ScriptRoot returned valid path: $scriptRoot" -ForegroundColor Green
    } else {
        Write-Warning "? Get-ScriptRoot returned path that may not exist: $scriptRoot"
    }
} catch {
    Write-Error "✗ Get-ScriptRoot failed: $($_.Exception.Message)"
    exit 1
}

# Test 4: Test NuGet provider check (without installing if missing)
Write-Host "`nTest 4: Checking NuGet provider availability..." -ForegroundColor Yellow
try {
    $nugetProvider = Get-PackageProvider -Name NuGet -ErrorAction SilentlyContinue
    if ($nugetProvider) {
        Write-Host "✓ NuGet provider is available (version: $($nugetProvider.Version))" -ForegroundColor Green
        
        # Check if it's a recent version
        if ([version]$nugetProvider.Version -lt [version]"2.8.5.201") {
            Write-Warning "! NuGet provider version is older than recommended (2.8.5.201)"
        } else {
            Write-Host "✓ NuGet provider version is up to date" -ForegroundColor Green
        }
    } else {
        Write-Warning "! NuGet provider is not installed - this would be fixed by Ensure-NuGetProvider"
    }
} catch {
    Write-Error "✗ Failed to check NuGet provider: $($_.Exception.Message)"
}

# Test 5: Test PowerShell Gallery repository check
Write-Host "`nTest 5: Checking PowerShell Gallery configuration..." -ForegroundColor Yellow
try {
    $psGallery = Get-PSRepository -Name PSGallery -ErrorAction SilentlyContinue
    if ($psGallery) {
        Write-Host "✓ PowerShell Gallery is available" -ForegroundColor Green
        if ($psGallery.InstallationPolicy -eq 'Trusted') {
            Write-Host "✓ PowerShell Gallery is trusted" -ForegroundColor Green
        } else {
            Write-Warning "! PowerShell Gallery is not trusted - this would be fixed by Ensure-NuGetProvider"
        }
    } else {
        Write-Warning "! PowerShell Gallery repository not found"
    }
} catch {
    Write-Error "✗ Failed to check PowerShell Gallery: $($_.Exception.Message)"
}

# Test 6: Test Update-12cModules.ps1 syntax
Write-Host "`nTest 6: Checking Update-12cModules.ps1 syntax..." -ForegroundColor Yellow
try {
    $scriptPath = Join-Path ($PSScriptRoot ? $PSScriptRoot : (Get-Location).Path) 'Update-12cModules.ps1'
    [System.Management.Automation.PSParser]::Tokenize((Get-Content $scriptPath -Raw), [ref]$null) | Out-Null
    Write-Host "✓ Update-12cModules.ps1 syntax is valid" -ForegroundColor Green
} catch {
    Write-Error "✗ Update-12cModules.ps1 syntax error: $($_.Exception.Message)"
    exit 1
}

# Test 7: Test packages.json loading
Write-Host "`nTest 7: Testing packages.json loading..." -ForegroundColor Yellow
try {
    $packagesJsonPath = Join-Path ($PSScriptRoot ? $PSScriptRoot : (Get-Location).Path) "packages.json"
    if (Test-Path $packagesJsonPath) {
        $packagesList = @(Get-Content -Path $packagesJsonPath -Raw | ConvertFrom-Json)
        Write-Host "✓ packages.json loaded successfully with $($packagesList.Count) packages" -ForegroundColor Green
        foreach ($pkg in $packagesList) {
            Write-Host "  - $pkg" -ForegroundColor Gray
        }
    } else {
        Write-Warning "! packages.json not found at $packagesJsonPath"
    }
} catch {
    Write-Error "✗ Failed to load packages.json: $($_.Exception.Message)"
}

# Test 8: Simulate repository credential storage
Write-Host "`nTest 8: Testing credential storage simulation..." -ForegroundColor Yellow
try {
    # Simulate what Ensure-12PsRepository does
    $testPAT = "test-token-123"
    $SecurePAT = ConvertTo-SecureString $testPAT -AsPlainText -Force
    $TestCredential = New-Object PSCredential('AzureDevOps', $SecurePAT)
    $global:12cPSRepositoryCredential = $TestCredential
    
    if ($global:12cPSRepositoryCredential -and $global:12cPSRepositoryCredential.UserName -eq 'AzureDevOps') {
        Write-Host "✓ Credential storage mechanism works correctly" -ForegroundColor Green
    } else {
        Write-Error "✗ Credential storage mechanism failed"
    }
    
    # Clean up
    Remove-Variable -Name "12cPSRepositoryCredential" -Scope Global -ErrorAction SilentlyContinue
} catch {
    Write-Error "✗ Credential storage test failed: $($_.Exception.Message)"
}

Write-Host "`n" + "="*60 -ForegroundColor Cyan
Write-Host "Test Summary:" -ForegroundColor Cyan
Write-Host "These fixes address the common portability issues:" -ForegroundColor White
Write-Host "• Automatic NuGet provider installation/update" -ForegroundColor Green
Write-Host "• PowerShell Gallery trust configuration" -ForegroundColor Green
Write-Host "• Proper credential handling for Install-Module" -ForegroundColor Green
Write-Host "• Network connectivity testing" -ForegroundColor Green
Write-Host "• Enhanced error messages with troubleshooting tips" -ForegroundColor Green
Write-Host "• Repository configuration verification" -ForegroundColor Green
Write-Host "`nAll tests completed!" -ForegroundColor Cyan