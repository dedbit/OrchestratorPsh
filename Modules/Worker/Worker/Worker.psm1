# Worker.psm1
# Module for batch processing of RoutingItems in specified workflow stages
# Worker functions receive the RoutingItem as their first parameter by default
# The stage function mapping supports both simple function names (strings) and scriptblocks with parameters

# Import OrchestratorRouting module for routing functions
# Try to import from relative path first, then from installed modules
try {
    $scriptRoot = $PSScriptRoot ? $PSScriptRoot : (Get-Location).Path
    $routingModulePath = Join-Path (Split-Path $scriptRoot -Parent) "../OrchestratorRouting/OrchestratorRouting/OrchestratorRouting.psm1"
    if (Test-Path $routingModulePath) {
        # Import local module with absolute path
        $resolvedPath = Resolve-Path $routingModulePath
        Import-Module $resolvedPath -Force -Global
    } else {
        Import-Module OrchestratorRouting -Force -Global
    }
} catch {
    Write-Warning "Could not import OrchestratorRouting module: $($_.Exception.Message)"
    throw "Worker module requires OrchestratorRouting module to be available"
}

# Get the list of worker function modules to import
function Get-WorkerFunctionModules {
    [CmdletBinding()]
    param()
    
    # Configure worker function modules - supports both paths and module names
    # This can be customized to include additional worker function modules
    $scriptRoot = $PSScriptRoot ? $PSScriptRoot : (Get-Location).Path
    
    $modules = @(
        # Example relative path modules (uncomment and modify as needed)
        # Join-Path $scriptRoot 'WorkerFunctions\Initialize.psm1',
        # Join-Path $scriptRoot 'WorkerFunctions\SetReadOnly.psm1',
        # Join-Path $scriptRoot 'WorkerFunctions\Upload.psm1',
        
        # Example installed module names (uncomment and modify as needed)
        # 'WorkerFunctionsInitialize',
        # 'WorkerFunctionsSetReadOnly',
        # 'WorkerFunctionsUpload'
    )
    
    # Filter out null/empty entries and ensure we always return an array
    $filteredModules = @($modules | Where-Object { $_ -and $_.Trim() })
    return ,$filteredModules
}

# Import worker function modules supporting both paths and installed module names
function Import-WorkerFunctionModules {
    [CmdletBinding()]
    param()
    
    $workerFunctionModules = Get-WorkerFunctionModules
    
    if (-not $workerFunctionModules -or $workerFunctionModules.Count -eq 0) {
        Write-Verbose "No worker function modules configured for import"
        return
    }
    
    Write-Verbose "Importing $($workerFunctionModules.Count) worker function modules..."
    
    foreach ($module in $workerFunctionModules) {
        try {
            if (Test-Path $module) {
                # Import as file path - resolve to absolute path
                $resolvedPath = Resolve-Path $module
                Import-Module $resolvedPath -Force -Global
                Write-Verbose "Imported worker function module from path: $resolvedPath"
            } elseif (Get-Module -ListAvailable | Where-Object { $_.Name -eq $module }) {
                # Import as installed module name
                Import-Module $module -Force -Global
                Write-Verbose "Imported worker function module by name: $module"
            } else {
                Write-Warning "Worker function module not found: $module"
            }
        } catch {
            Write-Warning "Failed to import worker function module '$module': $($_.Exception.Message)"
        }
    }
}



# Get the default stages for worker processing
function Get-DefaultStages {
    [CmdletBinding()]
    param()
    
    return @("initialize", "setreadonly", "upload")
}

# Get the stage to function mapping
function Get-StageFunctionMap {
    [CmdletBinding()]
    param()
    
    # Define stage to function mapping - easy to extend
    # Supports both function names (strings) and scriptblocks with parameters
    # All functions receive the RoutingItem as their first parameter
    # Examples:
    #   "initialize" = "Invoke-Initialize"  # Simple function call
    #   "upload" = { param($item) Invoke-Upload -Item $item -Timeout 300 }  # Scriptblock with parameters
    return @{
        "initialize" = "Invoke-Initialize"
        "setreadonly" = "Invoke-SetReadOnly"
        "upload" = "Invoke-Upload"
    }
}

<#
    .SYNOPSIS
    Processes a single RoutingItem using the specified stage function and updates its progress.

    .DESCRIPTION
    Invokes the provided stage function (string or scriptblock) for the given item and stage, updating progress to InProgress, Completed, or Failed.

    .PARAMETER Item
    The RoutingItem object to process. Example: @{ id = 'item-123'; State = 'Initialize'; Progress = 'Ready' }

    .PARAMETER StageFunction
    The function to call for processing. Example: 'Invoke-Initialize' or { param($item) Invoke-Initialize $item }. If passing a string, it has to be a function that is loaded in the module (scope issue)

    .PARAMETER Stage
    The stage name. Example: 'Initialize'

    .EXAMPLE
    Invoke-ItemProcessor -Item $item -StageFunction 'Invoke-Initialize' -Stage 'Initialize'
    Invoke-ItemProcessor -Item $item -StageFunction { Invoke-Initialize $args[0] } -Stage 'Initialize'
#>
function Invoke-ItemProcessor {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]$Item,
        [Parameter(Mandatory = $true)]$StageFunction,
        [Parameter(Mandatory = $true)][string]$Stage
    )
    
    try {
        Write-Host "Processing item '$($Item.id)' in stage '$Stage'..." -ForegroundColor White
        
        # Set progress to InProgress
        Update-ItemProgress -Item $Item -Progress "InProgress"
        
        # Call the corresponding processing function for this stage
        if ($StageFunction -is [scriptblock]) {
            # If it's a scriptblock, invoke it with the item as parameter
            & $StageFunction $Item
        } elseif ($StageFunction -is [string]) {
            # If it's a function name string, call the function with the item as parameter
            & $StageFunction $Item
        } else {
            throw "Invalid function mapping for stage '$Stage'. Must be either a function name (string) or scriptblock."
        }
        
        # If successful, set progress to Completed
        Update-ItemProgress -Item $Item -Progress "Completed"
        Write-Host "Item '$($Item.id)' in stage '$Stage' completed successfully" -ForegroundColor Green
        
    } catch {
        # On failure, set progress to Failed
        Update-ItemProgress -Item $Item -Progress "Failed"
        Write-Host "Item '$($Item.id)' in stage '$Stage' failed: $($_.Exception.Message)" -ForegroundColor Red
    }
}

# Process all items in a single stage
function Invoke-StageProcessor {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$Stage,
        [Parameter(Mandatory = $true)]$StageFunctionMap
    )
    
    Write-Host "Processing stage: $Stage" -ForegroundColor Yellow
    
    try {
        # Get all items in this stage with Ready progress
        $items = Get-RoutingItemsByState -State $Stage -Progress "Ready"
        
        if (-not $items -or $items.Count -eq 0) {
            Write-Host "No items found in stage '$Stage' with Ready progress" -ForegroundColor Gray
            return
        }
        
        Write-Host "Found $($items.Count) items in stage '$Stage'" -ForegroundColor Green
        
        # Get the processing function for this stage
        $stageFunction = $StageFunctionMap[$Stage]
        if (-not $stageFunction) {
            Write-Warning "No processing function mapped for stage '$Stage'. Skipping."
            return
        }
        
        # Check if the function exists (for string function names)
        if ($stageFunction -is [string] -and -not (Get-Command $stageFunction -ErrorAction SilentlyContinue)) {
            Write-Warning "Function '$stageFunction' not found for stage '$Stage'. Skipping."
            return
        }
        
        # Process each item
        foreach ($item in $items) {
            Invoke-ItemProcessor -Item $item -StageFunction $stageFunction -Stage $Stage
        }
        
    } catch {
        Write-Error "Failed to process stage '$Stage': $($_.Exception.Message)"
    }
}

# Generic worker that processes items in default or specified stages
# This is the initializer function, the first in the call chain. 
function Invoke-Worker {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string[]]$Stages = $null
    )
    
    # Use default stages if none specified (internalized)
    if (-not $Stages) {
        $Stages = Get-DefaultStages
    }
    
    $stageFunctionMap = Get-StageFunctionMap
    
    Write-Host "Starting worker for stages: $($Stages -join ', ')" -ForegroundColor Cyan
    
    foreach ($stage in $Stages) {
        Write-Host ""
        Invoke-StageProcessor -Stage $stage -StageFunctionMap $stageFunctionMap
    }
    
    Write-Host "`nWorker processing completed" -ForegroundColor Cyan
}



# Export the module functions
Export-ModuleMember -Function Invoke-Worker, Get-DefaultStages, Get-StageFunctionMap, Invoke-ItemProcessor, Get-WorkerFunctionModules, Import-WorkerFunctionModules, Invoke-StageProcessor

# Import worker function modules on module load
try {
    Import-WorkerFunctionModules
} catch {
    Write-Warning "Error during worker function module import: $($_.Exception.Message)"
}