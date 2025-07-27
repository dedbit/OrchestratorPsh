# OrchestratorRouting.psm1
# Module for item processing routing logic with progress and retry handling

# Define Progress enum with all supported progress states
enum ProgressState {
    Ready = 0
    InProgress = 1
    Completed = 2
    ValidationError = 3
    Failed = 4
    Hold = 5
}



# Import CosmosDB module for persistence
# Try to import from relative path first, then from installed modules
# Force local module to load instead of any system-wide module
try {
    $scriptRoot = $PSScriptRoot ? $PSScriptRoot : (Get-Location).Path
    $cosmosModulePath = Join-Path ($PSScriptRoot ? $PSScriptRoot : (Get-Location).Path) '..\..\..\Modules\CosmosDB\CosmosDBPackage\CosmosDBPackage.psm1'
    if (Test-Path $cosmosModulePath) {
        # Import local module with absolute path to override any system module
        $resolvedPath = Resolve-Path $cosmosModulePath
        Import-Module $resolvedPath -Force -Global
    } else {
        Import-Module CosmosDBPackage -Force -Global
    }
} catch {
    Write-Warning "Could not import CosmosDBPackage module: $($_.Exception.Message)"
    Write-Warning "Module will operate in test mode with in-memory storage"
    $Global:TestMode = $true
    $Global:TestItems = @{}
    
    # Provide mock implementations of CosmosDB functions for testing
    function global:Get-12cItem {
        param([string]$Id, [string]$DatabaseName, [string]$ContainerName)
        if ($Global:TestItems.ContainsKey($Id)) {
            return $Global:TestItems[$Id]
        }
        return $null
    }
    
    function global:Set-12cItem {
        param([object]$Item, [string]$DatabaseName, [string]$ContainerName)
        $Global:TestItems[$Item.id] = $Item
        return $Item
    }
    
    function global:Remove-12cItem {
        param([string]$Id, [string]$DatabaseName, [string]$ContainerName)
        if ($Global:TestItems.ContainsKey($Id)) {
            $Global:TestItems.Remove($Id)
        }
    }
    
    function global:Invoke-12cCosmosDbSqlQuery {
        param([string]$SqlQuery, [hashtable]$Parameters, [string]$DatabaseName, [string]$ContainerName)
        
        # Simple mock implementation for test queries
        $results = @()
        
        if ($SqlQuery -like "*WHERE c.State = @state*") {
            $state = $Parameters.state
            foreach ($item in $Global:TestItems.Values) {
                if ($item.State -eq $state) {
                    if ($SqlQuery -like "*AND c.Progress = @progress*") {
                        $progress = $Parameters.progress
                        if ($item.Progress -eq $progress) {
                            $results += $item
                        }
                    } else {
                        $results += $item
                    }
                }
            }
        } elseif ($SqlQuery -like "SELECT TOP*") {
            # Handle Get-RoutingItemsAll queries
            $count = 0
            $topValue = 100
            if ($SqlQuery -match "SELECT TOP (\d+)") {
                $topValue = [int]$matches[1]
            }
            foreach ($item in $Global:TestItems.Values) {
                if ($count -lt $topValue) {
                    $results += $item
                    $count++
                }
            }
        } else {
            # Return all items for other queries
            $results = $Global:TestItems.Values
        }
        
        return $results
    }
}




# Wrapper functions for CosmosDB operations with correct database and container names
function Invoke-Get12cItem {
    param([string]$Id)
    return Get-12cItem -Id $Id -DatabaseName "OrchestratorDb" -ContainerName "Items"
}

function Invoke-Set12cItem {
    param([object]$Item)
    return Set-12cItem -Item $Item -DatabaseName "OrchestratorDb" -ContainerName "Items"
}

function Invoke-Remove12cItem {
    param([string]$Id)
    Remove-12cItem -Id $Id -DatabaseName "OrchestratorDb" -ContainerName "Items"
}



# Helper function to normalize state names (case-insensitive)
function Get-NormalizedState {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$State
    )
    
    return $State.ToLower()
}

# Helper function to convert progress string to ProgressState enum
function ConvertTo-ProgressState {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [object]$Progress
    )
    
    # If already a ProgressState enum, return as-is
    if ($Progress -is [ProgressState]) {
        return $Progress
    }
    
    # Convert string to enum (case-insensitive)
    $progressString = $Progress.ToString().ToLower()
    switch ($progressString) {
        "ready" { return [ProgressState]::Ready }
        "inprogress" { return [ProgressState]::InProgress }
        "completed" { return [ProgressState]::Completed }
        "validationerror" { return [ProgressState]::ValidationError }
        "failed" { return [ProgressState]::Failed }
        "hold" { return [ProgressState]::Hold }
        default { 
            throw "Invalid progress value: '$Progress'. Valid values are: ready, inprogress, completed, validationerror, failed, hold"
        }
    }
}

# Helper function to convert ProgressState enum to lowercase string (for storage compatibility)
function ConvertFrom-ProgressState {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ProgressState]$ProgressState
    )
    
    switch ($ProgressState) {
        ([ProgressState]::Ready) { return "ready" }
        ([ProgressState]::InProgress) { return "inprogress" }
        ([ProgressState]::Completed) { return "completed" }
        ([ProgressState]::ValidationError) { return "validationerror" }
        ([ProgressState]::Failed) { return "failed" }
        ([ProgressState]::Hold) { return "hold" }
        default { return "ready" }
    }
}

# Helper function to validate item structure and ensure CosmosDB compatibility
function Assert-ItemStructure {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [object]$Item
    )
    
    # Handle both id (CosmosDB) and ItemId (legacy) properties
    if (-not $Item.id -and -not $Item.ItemId) {
        throw "Item must have an 'id' or 'ItemId' property"
    }
    
    # Ensure both id and ItemId exist and are synchronized
    if ($Item.id -and -not $Item.ItemId) {
        $Item | Add-Member -MemberType NoteProperty -Name 'ItemId' -Value $Item.id -Force
    }
    elseif ($Item.ItemId -and -not $Item.id) {
        $Item | Add-Member -MemberType NoteProperty -Name 'id' -Value $Item.ItemId -Force
    }
    
    if (-not $Item.PSObject.Properties.Name -contains 'State') {
        throw "Item must have a State property"
    }
    if (-not $Item.PSObject.Properties.Name -contains 'Progress') {
        throw "Item must have a Progress property"
    }
    if (-not $Item.PSObject.Properties.Name -contains 'RetryCount') {
        $Item | Add-Member -MemberType NoteProperty -Name 'RetryCount' -Value 0
    }
}

# Function to update the State of an item in CosmosDB
function Move-State {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ItemId,
        
        [Parameter(Mandatory = $true)]
        [string]$State
    )
    
    try {
        # Get the item from storage
        $item = Invoke-Get12cItem -Id $ItemId
        
        if (-not $item) {
            throw "Item with ID '$ItemId' not found"
        }
        
        # Ensure proper structure
        Assert-ItemStructure -Item $item
        
        # Update the state
        $normalizedState = Get-NormalizedState -State $State
        $item.State = $normalizedState
        
        # Save back to storage
        Invoke-Set12cItem -Item $item | Out-Null
        
        Write-Verbose "Item '$ItemId' state updated to '$normalizedState'"
    }
    catch {
        Write-Error "Failed to update state for item '$ItemId': $($_.Exception.Message)"
        throw
    }
}

# Function to update only the Progress property of an item
function Update-ItemProgress {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [object]$Item,
        
        [Parameter(Mandatory = $true)]
        [object]$Progress
    )
    
    Assert-ItemStructure -Item $Item
    
    # Convert progress to enum and then to storage string format
    $progressEnum = ConvertTo-ProgressState -Progress $Progress
    $progressString = ConvertFrom-ProgressState -ProgressState $progressEnum
    
    # Update progress property
    $Item.Progress = $progressString
    
    try {
        # Save updated item to storage
        Invoke-Set12cItem -Item $Item | Out-Null
        Write-Verbose "Item '$($Item.id)' progress updated to '$progressString'"
    }
    catch {
        Write-Error "Failed to update progress for item '$($Item.id)': $($_.Exception.Message)"
        throw
    }
}

# Main routing function that evaluates items and determines next actions
function Invoke-RoutingBySchema {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [object]$Item,
        
        [Parameter(Mandatory = $true)]
        [object]$RoutingSchema
    )
    
    Assert-ItemStructure -Item $Item
    
    # Ensure item exists in storage - save it if it doesn't exist or update if it does
    try {
        Invoke-Set12cItem -Item $Item | Out-Null
    }
    catch {
        Write-Error "Failed to save item to storage: $($_.Exception.Message)"
        throw
    }
    
    $currentState = Get-NormalizedState -State $Item.State
    $currentProgressEnum = ConvertTo-ProgressState -Progress $Item.Progress
    
    # Find routing configuration for current state
    $stateConfig = $null
    foreach ($key in $RoutingSchema.PSObject.Properties.Name) {
        if ((Get-NormalizedState -State $key) -eq $currentState) {
            $stateConfig = $RoutingSchema.$key
            break
        }
    }
    
    if (-not $stateConfig) {
        throw "No routing configuration found for state '$($Item.State)'"
    }
    
    if (-not $stateConfig.DefaultNextStage) {
        throw "DefaultNextStage is required for state '$($Item.State)'"
    }
    
    Write-Verbose "Processing item '$($Item.id)' in state '$currentState' with progress '$($Item.Progress)'"
    
    switch ($currentProgressEnum) {
        ([ProgressState]::Completed) {
            # Route to DefaultNextStage and set Progress to "ready"
            $nextStage = Get-NormalizedState -State $stateConfig.DefaultNextStage
            Move-State -ItemId $Item.id -State $nextStage
            
            # Get updated item and update progress
            $updatedItem = Invoke-Get12cItem -Id $Item.id
            Update-ItemProgress -Item $updatedItem -Progress ([ProgressState]::Ready)
            
            Write-Host "Item '$($Item.id)' completed, moved to stage '$nextStage' with progress 'ready'" -ForegroundColor Green
            return @{
                Action = "MovedToNextStage"
                NewState = $nextStage
                NewProgress = "ready"
                RetryCount = $updatedItem.RetryCount
            }
        }
        
        ([ProgressState]::Failed) {
            $maxRetries = if ($stateConfig.Retry) { [int]$stateConfig.Retry } else { 0 }
            $currentRetries = if ($Item.RetryCount) { [int]$Item.RetryCount } else { 0 }
            
            if ($currentRetries -lt $maxRetries) {
                # Increment RetryCount, set Progress to "ready", keep State
                $Item.RetryCount = $currentRetries + 1
                Update-ItemProgress -Item $Item -Progress ([ProgressState]::Ready)
                
                Write-Host "Item '$($Item.id)' failed, retry $($currentRetries + 1)/$maxRetries, set to ready" -ForegroundColor Yellow
                return @{
                    Action = "Retry"
                    NewState = $currentState
                    NewProgress = "ready"
                    RetryCount = $currentRetries + 1
                }
            }
            else {
                # No more retries allowed
                if ($stateConfig.DefaultFailStage) {
                    $failStage = Get-NormalizedState -State $stateConfig.DefaultFailStage
                    Move-State -ItemId $Item.id -State $failStage
                    
                    # Get updated item and update progress
                    $updatedItem = Invoke-Get12cItem -Id $Item.id
                    Update-ItemProgress -Item $updatedItem -Progress ([ProgressState]::Ready)
                    
                    Write-Host "Item '$($Item.id)' failed after $maxRetries retries, moved to fail stage '$failStage'" -ForegroundColor Red
                    return @{
                        Action = "MovedToFailStage"
                        NewState = $failStage
                        NewProgress = "ready"
                        RetryCount = $currentRetries
                    }
                }
                else {
                    # No fail stage defined, item remains in current state
                    Write-Host "Item '$($Item.id)' failed after $maxRetries retries, no fail stage defined, staying in '$currentState'" -ForegroundColor Red
                    return @{
                        Action = "StayInCurrentState"
                        NewState = $currentState
                        NewProgress = "failed"
                        RetryCount = $currentRetries
                    }
                }
            }
        }
        
        default {
            # For "ready", "inprogress", "hold", "validationerror" or any other progress state, no routing action needed
            Write-Verbose "Item '$($Item.id)' in progress state '$($Item.Progress)', no routing action needed"
            return @{
                Action = "NoAction"
                NewState = $currentState
                NewProgress = $Item.Progress
                RetryCount = $Item.RetryCount
            }
        }
    }
}

# Helper function to get an item by ID from storage
function Get-RoutingItem {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ItemId
    )
    
    try {
        $item = Invoke-Get12cItem -Id $ItemId
        
        if ($item) {
            Assert-ItemStructure -Item $item
        }
        return $item
    }
    catch {
        Write-Verbose "Item '$ItemId' not found in storage or error occurred: $($_.Exception.Message)"
        return $null
    }
}

# Helper function to create a new item and save it to storage
function New-RoutingItem {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ItemId,
        
        [Parameter(Mandatory = $true)]
        [string]$State,
        
        [Parameter(Mandatory = $false)]
        [object]$Progress = [ProgressState]::Ready,
        
        [Parameter(Mandatory = $false)]
        [int]$RetryCount = 0
    )
    
    # Convert progress to enum and then to storage string format
    $progressEnum = ConvertTo-ProgressState -Progress $Progress
    $progressString = ConvertFrom-ProgressState -ProgressState $progressEnum
    
    $item = [PSCustomObject]@{
        id = $ItemId
        partitionKey = $ItemId  # Use ItemId as partition key for new items
        ItemId = $ItemId  # For backward compatibility
        State = (Get-NormalizedState -State $State)
        Progress = $progressString
        RetryCount = $RetryCount
    }
    
    try {
        # Save to storage
        $savedItem = Invoke-Set12cItem -Item $item
        return $savedItem
    }
    catch {
        Write-Error "Failed to create item in storage: $($_.Exception.Message)"
        throw
    }
}

# Function to get routing items by state using SQL query
function Get-RoutingItemsByState {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$State,
        
        [Parameter(Mandatory = $false)]
        [object]$Progress
    )
    
    try {
        $normalizedState = Get-NormalizedState -State $State
        
        # Convert progress to string format if provided
        $progressString = $null
        if ($Progress) {
            $progressEnum = ConvertTo-ProgressState -Progress $Progress
            $progressString = ConvertFrom-ProgressState -ProgressState $progressEnum
        }
        
        # Use SQL query to get items by state and optionally by progress from CosmosDB
        if ($progressString) {
            $sqlQuery = "SELECT * FROM c WHERE c.State = @state AND c.Progress = @progress"
            $parameters = @{ 
                state = $normalizedState
                progress = $progressString
            }
        } else {
            $sqlQuery = "SELECT * FROM c WHERE c.State = @state"
            $parameters = @{ state = $normalizedState }
        }
        
        $items = Invoke-12cCosmosDbSqlQuery -SqlQuery $sqlQuery -Parameters $parameters -DatabaseName "OrchestratorDb" -ContainerName "Items"
        
        # Ensure item structure for all returned items
        foreach ($item in $items) {
            if ($item) {
                Assert-ItemStructure -Item $item
            }
        }
        
        return $items
    }
    catch {
        Write-Error "Failed to get routing items by state '$State'$(if ($Progress) { " and progress '$Progress'" }): $($_.Exception.Message)"
        throw
    }
}

# Function to get all routing items from storage
function Get-RoutingItemsAll {
    <#
    .SYNOPSIS
        Returns all routing items from storage.
    .PARAMETER Top
        The maximum number of items to return. Default is 100.
    .EXAMPLE
        Get-RoutingItemsAll
        Get-RoutingItemsAll -Top 50
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [int]$Top = 100
    )

    $sqlQuery = "SELECT TOP $Top * FROM c"
    $items = Invoke-12cCosmosDbSqlQuery -SqlQuery $sqlQuery -DatabaseName "OrchestratorDb" -ContainerName "Items"
    foreach ($item in $items) {
        if ($item) {
            Assert-ItemStructure -Item $item
        }
    }
    return $items
}


# Export the required functions
Export-ModuleMember -Function Invoke-RoutingBySchema, Move-State, Update-ItemProgress, Get-RoutingItemsByState, Get-RoutingItemsAll

# Export helper functions for testing
Export-ModuleMember -Function Get-RoutingItem, New-RoutingItem, Enable-TestMode, Disable-TestMode

# Export the ProgressState enum for external use
# Note: Enums are automatically available when using 'using module'

# Export Assert-ItemStructure function for external use
Export-ModuleMember -Function Assert-ItemStructure