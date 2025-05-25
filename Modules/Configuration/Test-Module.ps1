# Test-Module.ps1
# Script to test the Configuration module

# Modify the module import path to be relative to the script
$modulePath = Join-Path -Path (Split-Path -Path $MyInvocation.MyCommand.Path -Parent) -ChildPath "ConfigurationPackage.psm1"

# Import the module
Import-Module -Name $modulePath -Force

# Test Initialize-12Configuration
Write-Host "Testing Initialize-12Configuration..." -ForegroundColor Cyan
try {
    # Test with default path
    Initialize-12Configuration
    Write-Host "Initialize-12Configuration executed successfully with default path." -ForegroundColor Green

    # Test with custom path
    $customPath = Join-Path -Path (Split-Path -Path $MyInvocation.MyCommand.Path -Parent) -ChildPath "..\..\environments\dev.json"
    Initialize-12Configuration -ConfigFilePathOverride $customPath
    Write-Host "Initialize-12Configuration executed successfully with custom path." -ForegroundColor Green
} catch {
    Write-Error "Initialize-12Configuration test failed: $($_.Exception.Message)"
}

# Test Get-PSCommandPath
Write-Host "Testing Get-PSCommandPath..." -ForegroundColor Cyan
try {
    $commandPath = Get-PSCommandPath
    Write-Host "Get-PSCommandPath returned: $commandPath" -ForegroundColor Green
} catch {
    Write-Error "Get-PSCommandPath test failed: $($_.Exception.Message)"
}
