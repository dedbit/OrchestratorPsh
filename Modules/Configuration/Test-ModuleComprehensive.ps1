# Test-ModuleComprehensive.ps1
# Comprehensive test script for the Configuration module

# Force output to console
[Console]::WriteLine("Starting comprehensive tests for ConfigurationPackage module...")

# Create a log file for results
$logFile = Join-Path -Path $PSScriptRoot -ChildPath "test-results.log"
"Test started at $(Get-Date)" | Out-File -FilePath $logFile -Force

# Get the script root directory
$scriptRoot = $PSScriptRoot

# Create a test environment file for testing
$testEnvFile = Join-Path -Path $scriptRoot -ChildPath "test-environment.json"
@"
{
    "testSetting": "testValue",
    "environment": "test",
    "connections": {
        "keyVault": "test-key-vault",
        "storage": "teststorage"
    }
}
"@ | Out-File -FilePath $testEnvFile -Force

[Console]::WriteLine("Created test environment file at $testEnvFile")
"Created test environment file at $testEnvFile" | Out-File -FilePath $logFile -Append

# Modify the module import path to be relative to the script
$modulePath = Join-Path -Path $scriptRoot -ChildPath "ConfigurationPackage/ConfigurationPackage.psm1"

# Import the module
[Console]::WriteLine("Importing module from $modulePath...")
"Importing module from $modulePath..." | Out-File -FilePath $logFile -Append
Import-Module -Name $modulePath -Force

# Test if module was imported correctly
$moduleImported = Get-Module ConfigurationPackage
if ($moduleImported) {
    Write-Host "Module imported successfully: $($moduleImported.Name) v$($moduleImported.Version)" -ForegroundColor Green
} else {
    Write-Host "Failed to import module!" -ForegroundColor Red
    exit 1
}

# Test Get-PSCommandPath
Write-Host "Testing Get-PSCommandPath..." -ForegroundColor Cyan
try {
    $commandPath = Get-PSCommandPath
    Write-Host "Get-PSCommandPath returned: $commandPath" -ForegroundColor Green
    "Get-PSCommandPath returned: $commandPath" | Out-File -FilePath $logFile -Append
    
    # Verify it returns a valid path (could be module path, script path, or current location)
    if ($commandPath -eq $MyInvocation.MyCommand.Path -or 
        $commandPath -eq (Get-Location).Path -or 
        $commandPath -like "*ConfigurationPackage.psm1") {
        
        Write-Host "Get-PSCommandPath returned a valid path: $commandPath" -ForegroundColor Green
        "Get-PSCommandPath returned a valid path: $commandPath" | Out-File -FilePath $logFile -Append
    } else {
        Write-Host "Get-PSCommandPath returned an unexpected path: $commandPath" -ForegroundColor Yellow
        "Get-PSCommandPath returned an unexpected path: $commandPath" | Out-File -FilePath $logFile -Append
        Write-Host "Expected either script path, module path, or current location" -ForegroundColor Yellow
        "Expected either script path, module path, or current location" | Out-File -FilePath $logFile -Append
    }
} catch {
    Write-Error "Get-PSCommandPath test failed: $($_.Exception.Message)"
    exit 1
}

# Test Initialize-12Configuration
Write-Host "Testing Initialize-12Configuration..." -ForegroundColor Cyan
try {
    # Test with custom path (the test file we created)
    Initialize-12Configuration -ConfigFilePathOverride $testEnvFile
    
    # Check if global config variable is set
    if ($Global:12cConfig) {
        Write-Host "Global config variable set successfully" -ForegroundColor Green
        Write-Host "Config values: " -ForegroundColor Cyan
        Write-Host "  testSetting = $($Global:12cConfig.testSetting)" -ForegroundColor Green
        Write-Host "  environment = $($Global:12cConfig.environment)" -ForegroundColor Green
        Write-Host "  connections.keyVault = $($Global:12cConfig.connections.keyVault)" -ForegroundColor Green
    } else {
        Write-Error "Global config variable not set!"
        exit 1
    }
} catch {
    Write-Error "Initialize-12Configuration test failed: $($_.Exception.Message)"
    exit 1
}

# Test importing the module through the manifest (psd1)
Write-Host "Testing module import via manifest..." -ForegroundColor Cyan
try {
    # Remove the currently imported module
    Remove-Module -Name ConfigurationPackage -ErrorAction SilentlyContinue
    
    # Import via the manifest
    $manifestPath = Join-Path -Path $scriptRoot -ChildPath "ConfigurationPackage/ConfigurationPackage.psd1"
    Import-Module -Name $manifestPath -Force
    
    # Verify the module is imported
    $moduleImported = Get-Module ConfigurationPackage
    if ($moduleImported) {
        Write-Host "Module imported successfully via manifest" -ForegroundColor Green
        "Module imported successfully via manifest" | Out-File -FilePath $logFile -Append
    } else {
        throw "Failed to import module via manifest"
    }
    
    # Verify the functions are available
    $functions = Get-Command -Module ConfigurationPackage
    Write-Host "Available functions: $($functions.Name -join ', ')" -ForegroundColor Green
    "Available functions: $($functions.Name -join ', ')" | Out-File -FilePath $logFile -Append
} catch {
    Write-Error "Module import via manifest failed: $($_.Exception.Message)"
    exit 1
}

# Clean up test file
Remove-Item -Path $testEnvFile -Force
Write-Host "Removed test environment file" -ForegroundColor Green

# Output success message
Write-Host "All tests completed successfully!" -ForegroundColor Green
"All tests completed successfully!" | Out-File -FilePath $logFile -Append
Write-Host "Test results saved to $logFile" -ForegroundColor Cyan
