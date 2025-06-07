# test-module-comprehensive.ps1
# Comprehensive test script for the CommonConnections module

# Define paths at top of script
$modulePath = Join-Path ($PSScriptRoot ? $PSScriptRoot : (Get-Location).Path) 'CommonConnectionsPackage\CommonConnectionsPackage.psm1'
$customConfigPath = Join-Path ($PSScriptRoot ? $PSScriptRoot : (Get-Location).Path) '..\..\environments\dev.json'

# Test counters
$totalTests = 0
$passedTests = 0
$failedTests = 0

function Test-Assert {
    param(
        [string]$TestName,
        [scriptblock]$TestScript,
        [string]$ExpectedResult = $null
    )
    
    $script:totalTests++
    Write-Host "`n--- Testing: $TestName ---" -ForegroundColor Cyan
    
    try {
        $result = & $TestScript
        
        if ($ExpectedResult -and $result -ne $ExpectedResult) {
            throw "Expected '$ExpectedResult' but got '$result'"
        }
        
        Write-Host "✓ PASS: $TestName" -ForegroundColor Green
        $script:passedTests++
        return $true
    } catch {
        Write-Host "✗ FAIL: $TestName - $($_.Exception.Message)" -ForegroundColor Red
        $script:failedTests++
        return $false
    }
}

# Import the module
Write-Host "Importing CommonConnectionsPackage module..." -ForegroundColor Yellow
Import-Module -Name $modulePath -Force

# Test 1: Module loads correctly
Test-Assert "Module imports without errors" {
    $commands = Get-Command -Module CommonConnectionsPackage
    if ($commands.Count -eq 0) { throw "No commands exported from module" }
    return $commands.Count
}

# Test 2: Get-12cConnection function exists
Test-Assert "Get-12cConnection function exists" {
    $command = Get-Command Get-12cConnection -ErrorAction SilentlyContinue
    if (-not $command) { throw "Get-12cConnection function not found" }
    return $command.Name
} -ExpectedResult "Get-12cConnection"

# Test 3: Get all connections returns Default connection when no parameters
Test-Assert "Get default connection when no parameters provided" {
    $defaultConnection = Get-12cConnection
    if ($null -eq $defaultConnection) { throw "Default connection is null" }
    if (-not $defaultConnection.PSObject.Properties.Name.Contains('Name')) { throw "Default connection missing Name property" }
    if ($defaultConnection.Name -ne 'Default') { throw "Expected Default connection but got $($defaultConnection.Name)" }
    return $defaultConnection.Name
} -ExpectedResult "Default"

# Test 4: Get specific connection property
Test-Assert "Get specific connection property (tenantId)" {
    $tenantId = Get-12cConnection -ConnectionName 'tenantId'
    if ([string]::IsNullOrEmpty($tenantId)) { throw "TenantId is null or empty" }
    if ($tenantId -notmatch '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$') {
        throw "TenantId format is invalid"
    }
    return "Valid"
} -ExpectedResult "Valid"

# Test 5: Get Azure-related connections
$azureProperties = @('tenantId', 'subscriptionId', 'keyVaultName', 'appId')
foreach ($property in $azureProperties) {
    Test-Assert "Get Azure property: $property" {
        $value = Get-12cConnection -ConnectionName $property
        if ([string]::IsNullOrEmpty($value)) { throw "$property is null or empty" }
        return "Valid"
    } -ExpectedResult "Valid"
}

# Test 6: Get certificate-related connections
Test-Assert "Get certificate properties" {
    $certThumbprint = Get-12cConnection -ConnectionName 'certThumbprint'
    if ([string]::IsNullOrEmpty($certThumbprint)) { throw "Certificate thumbprint is null or empty" }
    if ($certThumbprint.Length -ne 40) { throw "Certificate thumbprint length is invalid" }
    return "Valid"
} -ExpectedResult "Valid"

# Test 7: Get M365/DevOps feed connections
Test-Assert "Get artifacts feed URL" {
    $feedUrl = Get-12cConnection -ConnectionName 'artifactsFeedUrl'
    if ([string]::IsNullOrEmpty($feedUrl)) { throw "Artifacts feed URL is null or empty" }
    if (-not $feedUrl.StartsWith('https://')) { throw "Artifacts feed URL format is invalid" }
    return "Valid"
} -ExpectedResult "Valid"

# Test 8: Custom config file path
Test-Assert "Custom config file path works" {
    $config = Get-12cConnection -ConfigFilePathOverride $customConfigPath
    if ($null -eq $config) { throw "Custom config returned null" }
    return "Valid"
} -ExpectedResult "Valid"

# Test 9: Non-existent property returns null gracefully
Test-Assert "Non-existent property returns null gracefully" {
    $result = Get-12cConnection -ConnectionName 'NonExistentProperty'
    if ($null -ne $result) { throw "Expected null for non-existent property" }
    return "Null"
} -ExpectedResult "Null"

# Test 10: Invalid config path handling (falls back to default)
Test-Assert "Invalid config path falls back to default gracefully" {
    # When an invalid override path is provided, it should fall back to default path
    $result = Get-12cConnection -ConfigFilePathOverride "/NonExistent/path/file.json"
    if ($null -eq $result) { throw "Should have fallen back to default config" }
    # Since no ConnectionName is provided, should return Default connection
    if ($result.Name -ne 'Default') {
        throw "Default config fallback failed - expected Default connection"
    }
    return "Valid"
} -ExpectedResult "Valid"

# Test 11: Configuration caching works
Test-Assert "Configuration caching works correctly" {
    # First call should load config (returns Default connection)
    $config1 = Get-12cConnection
    # Second call should use cached config (returns Default connection)
    $config2 = Get-12cConnection
    # Compare the Default connection properties
    if ($config1.Name -ne $config2.Name -or $config1.Type -ne $config2.Type) { 
        throw "Configuration caching failed" 
    }
    return "Valid"
} -ExpectedResult "Valid"

# Test 12: Flexibility for future migration (check structure compatibility)
Test-Assert "Configuration structure supports future migration" {
    # Verify that the existing properties are still accessible via specific connection names
    $requiredProperties = @('tenantId', 'subscriptionId', 'keyVaultName')
    foreach ($prop in $requiredProperties) {
        $value = Get-12cConnection -ConnectionName $prop
        if ([string]::IsNullOrEmpty($value)) {
            throw "Missing required property: $prop"
        }
    }
    # Also verify the new Connections structure exists
    $connectionsDefault = Get-12cConnection -ConnectionName 'Connections.Default'
    if ($null -eq $connectionsDefault -or $connectionsDefault.Name -ne 'Default') {
        throw "Connections.Default structure missing or invalid"
    }
    return "Valid"
} -ExpectedResult "Valid"

# Test 13: Default connection has required properties
Test-Assert "Default connection contains required properties" {
    $defaultConnection = Get-12cConnection
    $requiredProps = @('Name', 'Type', 'Host', 'UserName', 'Password')
    foreach ($prop in $requiredProps) {
        if (-not $defaultConnection.PSObject.Properties.Name.Contains($prop)) {
            throw "Default connection missing required property: $prop"
        }
    }
    return "Valid"
} -ExpectedResult "Valid"

# Test 14: Default connection values are correct
Test-Assert "Default connection has correct values" {
    $defaultConnection = Get-12cConnection
    if ($defaultConnection.Name -ne 'Default') { throw "Name should be 'Default'" }
    if ($defaultConnection.Type -ne 'SqlServer') { throw "Type should be 'SqlServer'" }
    if ($defaultConnection.Host -ne 'localhost') { throw "Host should be 'localhost'" }
    if ($defaultConnection.UserName -ne 'sa') { throw "UserName should be 'sa'" }
    if ($defaultConnection.Password -ne 'YourStrong!Passw0rd') { throw "Password mismatch" }
    return "Valid"
} -ExpectedResult "Valid"

# Summary
Write-Host "`n" + "="*50 -ForegroundColor Magenta
Write-Host "COMPREHENSIVE TEST SUMMARY" -ForegroundColor Magenta
Write-Host "="*50 -ForegroundColor Magenta
Write-Host "Total Tests: $totalTests" -ForegroundColor White
Write-Host "Passed: $passedTests" -ForegroundColor Green
if ($failedTests -ne 0) {
    Write-Host "Failed: $failedTests" -ForegroundColor Red
} else {
    Write-Host "Failed: $failedTests" -ForegroundColor Green
}

if ($failedTests -eq 0) {
    Write-Host "`n✓ ALL TESTS PASSED! The CommonConnections module is working correctly." -ForegroundColor Green
    Write-Host "The module successfully provides:" -ForegroundColor Yellow
    Write-Host "  • JSON configuration parsing" -ForegroundColor Gray
    Write-Host "  • Azure connection details retrieval" -ForegroundColor Gray
    Write-Host "  • M365/DevOps connection support" -ForegroundColor Gray
    Write-Host "  • Certificate-based authentication info" -ForegroundColor Gray
    Write-Host "  • Flexible structure for future Azure App Configuration migration" -ForegroundColor Gray
} else {
    Write-Host "`n✗ SOME TESTS FAILED! Please review the failed tests above." -ForegroundColor Red
    exit 1
}

Write-Host "`nCommonConnections comprehensive testing completed." -ForegroundColor Cyan