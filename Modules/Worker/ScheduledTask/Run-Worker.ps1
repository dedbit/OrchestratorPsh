# Run-Worker.ps1
# Main script to execute the Worker module for batch processing
# This script loads the Worker module and invokes the main worker process

param(
    [string[]]$Stages = $null,
    [switch]$Verbose
)

$ErrorActionPreference = 'Stop'

if ($Verbose) {
    $VerbosePreference = 'Continue'
}

try {
    Write-Host "Starting Worker execution..." -ForegroundColor Cyan
    Write-Host "Timestamp: $(Get-Date)" -ForegroundColor Gray
    
    # Get the script directory using robust path construction pattern
    $scriptRootPath = $PSScriptRoot ? $PSScriptRoot : (Get-Location).Path
    $workerModulePath = Join-Path (Split-Path $scriptRootPath -Parent) "Worker\Worker.psd1"
    
    # Validate that the Worker module exists
    if (-not (Test-Path $workerModulePath)) {
        throw "Worker module not found at $workerModulePath"
    }
    
    Write-Host "Loading Worker module from: $workerModulePath" -ForegroundColor Yellow
    
    # Import the Worker module
    Import-Module $workerModulePath -Force
    
    # Execute the worker with specified or default stages
    if ($Stages) {
        Write-Host "Running worker with custom stages: $($Stages -join ', ')" -ForegroundColor Yellow
        Invoke-Worker -Stages $Stages
    } else {
        Write-Host "Running worker with default stages" -ForegroundColor Yellow
        Invoke-Worker
    }
    
    Write-Host "Worker execution completed successfully" -ForegroundColor Green
    Write-Host "Timestamp: $(Get-Date)" -ForegroundColor Gray
    
} catch {
    Write-Host "ERROR: Worker execution failed: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Timestamp: $(Get-Date)" -ForegroundColor Gray
    
    # Log the full error details for debugging
    Write-Host "Full error details:" -ForegroundColor Red
    Write-Host $_.Exception.ToString() -ForegroundColor Red
    
    exit 1
}