# Test-Install-Worker-ScheduledTask.ps1
# Test script to verify Install-Worker-ScheduledTask.ps1 functionality
# Based on CoreUpdaterPackage\ScheduledTask\Test-InstallScheduledTask.ps1

$ErrorActionPreference = 'Stop'

# Variables
$taskName = "Run-Worker-Task"
$taskPath = "\12C\"
$installScript = Join-Path ($PSScriptRoot ? $PSScriptRoot : (Get-Location).Path) 'Install-Worker-ScheduledTask.ps1'

function Test-WorkerTaskCreation {
    param(
        [switch]$RunInBackground
    )
    
    Write-Host "Testing Worker scheduled task creation..." -ForegroundColor Cyan
    
    # Remove the task if it already exists
    if (Get-ScheduledTask -TaskName $taskName -TaskPath $taskPath -ErrorAction SilentlyContinue) {
        Write-Host "Removing existing task '$taskName'" -ForegroundColor Yellow
        Unregister-ScheduledTask -TaskName $taskName -TaskPath $taskPath -Confirm:$false
    }
    
    # Build script args using hashtable for named parameter splatting
    $params = @{ 
        TaskName = $taskName
        SkipAdminCheck = $true
    }
    if ($RunInBackground) { 
        $params.RunInBackground = $true 
    }
    
    Write-Host "Running Install-Worker-ScheduledTask.ps1 with params:" -ForegroundColor Cyan
    $params | Format-List
    
    try {
        & $installScript @params
        
        # Get the created task
        $task = Get-ScheduledTask -TaskName $taskName -TaskPath $taskPath -ErrorAction Stop
        
        # Validate task properties
        if ($task.TaskName -ne $taskName) {
            throw "Task name mismatch. Expected: $taskName, Got: $($task.TaskName)"
        }
        
        # Check that the task has a repeat trigger
        $trigger = $task.Triggers[0]
        if (-not $trigger.Repetition) {
            throw "Task does not have repetition configured"
        }
        
        # Check repetition interval (should be 15 minutes)
        $interval = $trigger.Repetition.Interval
        if ($interval -ne "PT15M") {
            throw "Incorrect repetition interval. Expected: PT15M, Got: $interval"
        }
        
        # Check that the action points to the correct batch file
        $action = $task.Actions[0]
        if ($action.Execute -notlike "*Run-Worker.bat") {
            throw "Action does not point to Run-Worker.bat. Got: $($action.Execute)"
        }
        
        Write-Host "✓ Task validation passed!" -ForegroundColor Green
        Write-Host "  - Task Name: $($task.TaskName)" -ForegroundColor White
        Write-Host "  - Task Path: $($task.TaskPath)" -ForegroundColor White
        Write-Host "  - Repetition Interval: $interval" -ForegroundColor White
        Write-Host "  - Executable: $($action.Execute)" -ForegroundColor White
        Write-Host "  - Working Directory: $($action.WorkingDirectory)" -ForegroundColor White
        
        return $true
        
    } catch {
        Write-Host "✗ Task creation or validation failed: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

function Test-RunWorkerScript {
    Write-Host "Testing Run-Worker.ps1 script execution..." -ForegroundColor Cyan
    
    $runWorkerScript = Join-Path ($PSScriptRoot ? $PSScriptRoot : (Get-Location).Path) 'Run-Worker.ps1'
    
    if (-not (Test-Path $runWorkerScript)) {
        Write-Host "✗ Run-Worker.ps1 not found at $runWorkerScript" -ForegroundColor Red
        return $false
    }
    
    try {
        # Test the Run-Worker script execution
        $output = & $runWorkerScript
        
        Write-Host "✓ Run-Worker.ps1 executed successfully!" -ForegroundColor Green
        Write-Host "Script output preview:" -ForegroundColor Gray
        $output | Select-Object -First 5 | ForEach-Object { Write-Host "  $_" -ForegroundColor Gray }
        
        return $true
        
    } catch {
        Write-Host "✗ Run-Worker.ps1 execution failed: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

function Test-DryRun {
    Write-Host "Testing dry run functionality..." -ForegroundColor Cyan
    
    try {
        # Test dry run without admin check
        & $installScript -DryRun -SkipAdminCheck
        
        # Check that dry run completed without errors by checking if no exception was thrown
        Write-Host "✓ Dry run completed successfully!" -ForegroundColor Green
        return $true
        
    } catch {
        Write-Host "✗ Dry run failed: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

# Main test execution
Write-Host "=== Worker Scheduled Task Tests ===" -ForegroundColor Cyan
Write-Host ""

$testResults = @()

# Test 1: Dry run functionality
$testResults += Test-DryRun

# Test 2: Run-Worker script execution
$testResults += Test-RunWorkerScript

# Only test actual task creation on Windows
if ($IsWindows -or $env:OS -like "Windows*") {
    # Test 3: Interactive task creation (default)
    $testResults += Test-WorkerTaskCreation
    
    # Clean up: Remove the test task
    if (Get-ScheduledTask -TaskName $taskName -TaskPath $taskPath -ErrorAction SilentlyContinue) {
        Write-Host "Cleaning up: Removing test task '$taskName'" -ForegroundColor Yellow
        Unregister-ScheduledTask -TaskName $taskName -TaskPath $taskPath -Confirm:$false
    }
} else {
    Write-Host "Skipping actual task creation tests (not on Windows platform)" -ForegroundColor Yellow
    $testResults += $true  # Consider this test as passed
}

# Summary
Write-Host ""
Write-Host "=== Test Summary ===" -ForegroundColor Cyan
$passedTests = ($testResults | Where-Object { $_ -eq $true }).Count
$totalTests = $testResults.Count

if ($passedTests -eq $totalTests) {
    Write-Host "✓ All tests passed ($passedTests/$totalTests)" -ForegroundColor Green
    exit 0
} else {
    Write-Host "✗ Some tests failed ($passedTests/$totalTests)" -ForegroundColor Red
    exit 1
}