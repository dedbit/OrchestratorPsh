# Worker.TestHelpers.psm1
# Test helper functions for Worker module

# Import OrchestratorRouting TestHelpers for Enable-TestMode
try {
    $scriptRoot = $PSScriptRoot ? $PSScriptRoot : (Get-Location).Path
    $routingTestHelpersPath = Join-Path (Split-Path $scriptRoot -Parent) "../OrchestratorRouting/OrchestratorRouting/OrchestratorRouting.TestHelpers.psm1"
    if (Test-Path $routingTestHelpersPath) {
        $resolvedPath = Resolve-Path $routingTestHelpersPath
        Import-Module $resolvedPath -Force -Global
    }
} catch {
    Write-Warning "Could not import OrchestratorRouting TestHelpers: $($_.Exception.Message)"
}

# Simulates a task that sleeps for 1 second and throws an exception randomly in 50% of cases
function Invoke-TestTask {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$false)]$Item
    )
    
    if ($Item) {
        Write-Verbose "Starting test task execution for item '$($Item.id)'"
    } else {
        Write-Verbose "Starting test task execution"
    }
    
    # Sleep for 1 second
    Start-Sleep -Seconds 1
    
    # Throw exception randomly in 50% of cases
    $randomValue = Get-Random -Minimum 1 -Maximum 101
    if ($randomValue -le 50) {
        throw "Test task failed randomly (random value: $randomValue)"
    }
    
    Write-Verbose "Test task completed successfully"
}

# Processes all RoutingItems in state "TestTask" and progress "Ready"
function Invoke-ProcessTestTask {
    [CmdletBinding()]
    param()
    
    Write-Host "Processing TestTask items..." -ForegroundColor Cyan
    
    try {
        # Get all items in TestTask state with Ready progress
        $items = Get-RoutingItemsByState -State "TestTask" -Progress "Ready"
        
        if (-not $items -or $items.Count -eq 0) {
            Write-Host "No items found in TestTask state with Ready progress" -ForegroundColor Yellow
            return
        }
        
        Write-Host "Found $($items.Count) items to process" -ForegroundColor Green
        
        foreach ($item in $items) {
            try {
                Write-Host "Processing item '$($item.id)'..." -ForegroundColor White
                
                # Set progress to InProgress
                Update-ItemProgress -Item $item -Progress "InProgress"
                
                # Try to execute the test task
                Invoke-TestTask
                
                # If successful, set progress to Completed
                Update-ItemProgress -Item $item -Progress "Completed"
                Write-Host "Item '$($item.id)' completed successfully" -ForegroundColor Green
                
            } catch {
                # If exception occurs, set progress to Failed
                Update-ItemProgress -Item $item -Progress "Failed"
                Write-Host "Item '$($item.id)' failed: $($_.Exception.Message)" -ForegroundColor Red
            }
        }
        
        Write-Host "TestTask processing completed" -ForegroundColor Cyan
        
    } catch {
        Write-Error "Failed to process TestTask items: $($_.Exception.Message)"
        throw
    }
}

# Add a proxy function for Get-RoutingItemsByState to accept any parameters
function Get-RoutingItemsByState {
    param(
        [Parameter(Mandatory=$true)] $State,
        [Parameter(Mandatory=$false)] $Progress,
        [Parameter(Mandatory=$false)] $SqlQuery,
        [Parameter(Mandatory=$false)] $Parameters
    )
    # Return empty array for test isolation
    @()
}

Export-ModuleMember -Function Invoke-TestTask, Invoke-ProcessTestTask, Enable-TestMode, Disable-TestMode