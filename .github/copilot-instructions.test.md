# PowerShell Testing Instructions

## Recommended Testing Approach: Pester Framework (Unit Tests)

### Pester Version
- Use Pester v5+ (5.7.1 or higher recommended)
- Check with: `Get-Module -Name Pester -ListAvailable | Select-Object -Property Name, Version`
- If not installed or outdated: `Install-Module -Name Pester -Force -SkipPublisherCheck -MinimumVersion 5.7.1`

### Import and Setup
```powershell
# In your test script
BeforeAll {
    # Ensure Pester v5+ is used
    $pesterModule = Get-Module -Name Pester -ListAvailable | 
        Where-Object Version -ge '5.0.0' | 
        Sort-Object Version -Descending | 
        Select-Object -First 1
    
    if (-not $pesterModule) {
        throw "Pester 5.0.0+ is required to run these tests"
    }
    
    # Import test target module with absolute path for reliability
    $modulePath = Join-Path ($PSScriptRoot ? $PSScriptRoot : (Get-Location).Path) '..\Modules\Worker\Worker.psd1'
    Import-Module $modulePath -Force
}
```

### Why Pester?
- **No production code changes required** - Mock any function without modifying source
- **Built into PowerShell** - Standard testing framework
- **Isolated test runs** - Each test can have its own mocks
- **No global scope pollution** - Mocks are scoped to test blocks

### Basic Pester Test Structure

```powershell
BeforeAll {
    # Import modules under test
    $modulePath = Join-Path ($PSScriptRoot ? $PSScriptRoot : (Get-Location).Path) '..\Modules\Worker\Worker.psd1'
    Import-Module $modulePath -Force
}

Describe "Worker Module Tests" {
    BeforeEach {
        # Initialize test data for each test
        $script:TestItems = @{}
    }
    
    Context "When processing items" {
        BeforeEach {
            # Mock external dependencies
            Mock Get-12cItem {
                param($Id)
                return $script:TestItems[$Id]
            }
            
            Mock Set-12cItem {
                param($Item)
                $script:TestItems[$Item.id] = $Item
                return $Item
            }
            
            Mock Invoke-12cCosmosDbSqlQuery {
                param($SqlQuery, $Parameters)
                $script:TestItems.Values | Where-Object { $_.State -eq $Parameters.state }
            }
        }
        
        It "Should process Initialize stage items" {
            # Arrange
            $testItem = @{
                id = "test-123"
                State = "Initialize"
                Progress = "Ready"
            }
            $script:TestItems[$testItem.id] = $testItem
            
            # Act
            Invoke-Worker -Stages @("Initialize")
            
            # Assert
            $script:TestItems[$testItem.id].Progress | Should -BeIn @("Completed", "Failed")
        }
    }
}
```

### Mocking Complex Scenarios

```powershell
Describe "Error Handling Tests" {
    It "Should handle CosmosDB failures gracefully" {
        # Mock to simulate failure
        Mock Set-12cItem { throw "CosmosDB connection failed" }
        
        # Test error handling
        { New-RoutingItem -ItemId "test-123" -State "Initialize" } | Should -Throw
    }
    
    It "Should retry on transient failures" {
        # Mock with counter to fail first 2 calls
        $script:CallCount = 0
        Mock Get-12cItem {
            $script:CallCount++
            if ($script:CallCount -lt 3) {
                throw "Transient error"
            }
            return @{ id = "test-123" }
        }
        
        # Should succeed after retries
        $result = Get-RoutingItemWithRetry -ItemId "test-123"
        $result.id | Should -Be "test-123"
        $script:CallCount | Should -Be 3
    }
}
```

### Testing Private Functions

```powershell
Describe "Private Function Tests" {
    It "Should test internal module functions" {
        # Use InModuleScope to access private functions
        InModuleScope Worker {
            # Can now test private functions
            $result = Test-InternalValidation -Item @{ id = "123" }
            $result | Should -Be $true
        }
    }
}
```

### Integration Testing (Recommended: Direct Script Execution)

- Integration tests should use production modules and real dependencies.
- Do **not** use Pester for integration tests; do **not** mock dependencies.
- Run integration test scripts directly in PowerShell:

```powershell
# Example: Run integration test script directly
cd C:\dev\12C\OrchestratorPsh2\Modules\Worker
.\TestAllAzureUser.ps1
```

- Integration tests should validate end-to-end flows and real system behavior.
- All integration tests should be referenced in the root orchestration scripts (e.g. `TestAllAzureUser.ps1`, `TestAllCert.ps1`).
- For authentication. Use certificate based authentication (Connect-12AzureWithCertificate)  if possible. Otherwise use user based authentication (Connect-12Azure). Note that test has to be added to `TestAllCert.ps1` or `TestAllAzureUser.ps1` accordingly. 
- Use assertions and output checks in the script itself, not Pester blocks.
- Integration tests should include assertions to validate expected outcomes, but should not require installing or importing any additional modules for assertions; use simple PowerShell functions or built-in logic.

### Test File Organization

```
/Tests
    /Unit
        Worker.Tests.ps1
        OrchestratorRouting.Tests.ps1
    /Integration  
        EndToEnd.Tests.ps1
    TestHelpers.psm1  # Shared test utilities
```

## Benefits Over TestMode Pattern

- **No global state issues** - Each test is isolated
- **No import order problems** - Pester handles scoping for unit tests
- **Easier debugging** - Clear mock boundaries for unit tests
- **Better error messages** - Pester provides detailed failures for unit tests
- **Standard tooling** - Works with CI/CD pipelines
- **Integration tests validate real system behavior**

## Legacy TestMode Pattern (Not Recommended)

[Previous TestMode content remains for reference but is marked as not recommended]