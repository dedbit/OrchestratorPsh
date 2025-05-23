# Test-Module.ps1
# Script to test the Configuration module

# Modify the module import path to be relative to the script
$modulePath = Join-Path -Path (Split-Path -Path $MyInvocation.MyCommand.Path -Parent) -ChildPath "Configuration.psm1"

# Import the module
Import-Module -Name $modulePath -Force

# Test Connect-12Configuration
Write-Host "Testing Connect-12Configuration..." -ForegroundColor Cyan
try {
    Connect-12Configuration
    Write-Host "Connect-12Configuration executed successfully." -ForegroundColor Green
} catch {
    Write-Error "Connect-12Configuration test failed: $($_.Exception.Message)"
}

# Test Get-PSCommandPath
Write-Host "Testing Get-PSCommandPath..." -ForegroundColor Cyan
try {
    $commandPath = Get-PSCommandPath
    Write-Host "Get-PSCommandPath returned: $commandPath" -ForegroundColor Green
} catch {
    Write-Error "Get-PSCommandPath test failed: $($_.Exception.Message)"
}
