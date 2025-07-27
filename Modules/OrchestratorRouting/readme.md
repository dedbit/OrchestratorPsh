# OrchestratorRouting Module

A PowerShell module for implementing routing logic for item processing with progress and retry handling, integrated with CosmosDB for persistent storage.

For detailed architecture information, see [Architecture.md](./Architecture.md).

## Prerequisites

Before using this module, ensure you have:

1. **CosmosDB Module**: The module depends on the CosmosDBPackage module for persistence
2. **Global Configuration**: Global 12c configuration must be initialized with CosmosDB connection details
3. **Azure Access**: Appropriate Azure Key Vault permissions for CosmosDB connection strings

## Installation Options

### Option 1: Local Development Installation
```powershell
# Import the CosmosDB module first (if not already loaded)
Import-Module -Path ".\Modules\CosmosDB\CosmosDBPackage\CosmosDBPackage.psd1"

# Import the routing module
Import-Module -Path ".\Modules\OrchestratorRouting\OrchestratorRouting\OrchestratorRouting.psd1"
```

### Option 2: Copy to PowerShell Module Path
```powershell
# Copy both modules to your PowerShell module directory
Copy-Item -Path ".\Modules\CosmosDB\CosmosDBPackage" -Destination "$env:PSModulePath.Split(';')[0]\CosmosDBPackage" -Recurse
Copy-Item -Path ".\Modules\OrchestratorRouting\OrchestratorRouting" -Destination "$env:PSModulePath.Split(';')[0]\OrchestratorRouting" -Recurse

Import-Module -Name CosmosDBPackage
Import-Module -Name OrchestratorRouting
```

## Configuration Setup

Before using the routing functions, initialize the global configuration:

```powershell
# Initialize global configuration (example)
Initialize-12Configuration -ConfigurationFilePath "path/to/config.json"

# Or set manually
$Global:12cConfig = @{
    keyVaultName = "your-keyvault-name"
    cosmosDbAccountName = "your-cosmosdb-account"
}
```

## Usage

### Basic Routing with Schema

```powershell
# Import the module
Import-Module -Name OrchestratorRouting

# Define routing schema
$routingSchema = @{
    "stage1" = @{
        "DefaultNextStage" = "stage2"
        "DefaultFailStage" = "failed_stage"
        "Retry" = 3
    }
    "stage2" = @{
        "DefaultNextStage" = "completed_stage"
        "Retry" = 1
    }
} | ConvertTo-Json | ConvertFrom-Json

# Create an item (saves to CosmosDB)
$item = New-RoutingItem -ItemId "example-1" -State "stage1" -Progress "ready"

# Process with worker service
$processedItem = Test-WorkerService -Item $item -SimulateSuccess

# Apply routing logic
$routingResult = Invoke-RoutingBySchema -Item $processedItem -RoutingSchema $routingSchema
```

### Loading Schema from JSON File

```powershell
# Load routing schema from file
$routingSchema = Get-Content "routing-schema.json" -Raw | ConvertFrom-Json

# Use the schema with routing logic
$result = Invoke-RoutingBySchema -Item $item -RoutingSchema $routingSchema
```

### Manual State and Progress Management

```powershell
# Update progress using enum values (recommended)
Update-ItemProgress -Item $item -Progress ([ProgressState]::InProgress)
Update-ItemProgress -Item $item -Progress ([ProgressState]::ValidationError)
Update-ItemProgress -Item $item -Progress ([ProgressState]::Hold)

# Update progress using string values (backward compatibility)
Update-ItemProgress -Item $item -Progress "inprogress"
Update-ItemProgress -Item $item -Progress "validationerror"
Update-ItemProgress -Item $item -Progress "hold"

# Move item to different state (updates in CosmosDB)
Move-State -ItemId $item.id -State "stage2"

# Retrieve item (from CosmosDB)
$currentItem = Get-RoutingItem -ItemId $item.id
```

## Available Functions

### Core Routing Functions

- **`Invoke-RoutingBySchema`**: Main routing function that evaluates item progress and determines next routing action
- **`Move-State`**: Updates the State property of an item (only used by routing logic)
- **`Update-ItemProgress`**: Updates only the Progress property of an item
- **`Test-WorkerService`**: Example worker function that simulates item processing

### Helper Functions

- **`New-RoutingItem`**: Creates a new item and saves it to CosmosDB
- **`Get-RoutingItem`**: Retrieves an item by ID from CosmosDB

## Data Storage

This module uses **CosmosDB** for persistent storage of items. All item state changes are automatically persisted to CosmosDB:

- **Item Creation**: `New-RoutingItem` saves new items to CosmosDB
- **State Updates**: `Move-State` updates items in CosmosDB
- **Progress Updates**: `Update-ItemProgress` saves progress changes to CosmosDB  
- **Item Retrieval**: `Get-RoutingItem` loads items from CosmosDB

### Item Structure in CosmosDB

Items stored in CosmosDB have the following structure:

```json
{
  "id": "item-identifier",           // CosmosDB document ID
  "ItemId": "item-identifier",       // Backward compatibility
  "State": "current_state",          // Current processing state (normalized to lowercase)
  "Progress": "current_progress",    // Current progress status
  "RetryCount": 0                    // Number of retry attempts
}
```

## Routing Schema Format

The routing schema is a JSON object where each key represents a state/stage name:

```json
{
  "stage_name": {
    "DefaultNextStage": "next_stage",    // Required: Where to go on completion
    "DefaultFailStage": "fail_stage",    // Optional: Where to go on failure after retries
    "Retry": 3                           // Optional: Number of retries allowed (default: 0)
  }
}
```

## Progress Values

The system uses a **ProgressState enum** with these progress values:

- **`Ready`** (stored as `"ready"`): Item is ready for processing
- **`InProgress`** (stored as `"inprogress"`): Item is currently being processed
- **`Completed`** (stored as `"completed"`): Item processing completed successfully
- **`ValidationError`** (stored as `"validationerror"`): Item failed validation and requires attention
- **`Failed`** (stored as `"failed"`): Item processing failed
- **`Hold`** (stored as `"hold"`): Item is on hold and should not be processed

### Backward Compatibility

The module maintains full backward compatibility with string-based progress values. You can use either:
- Enum values: `[ProgressState]::Ready`, `[ProgressState]::ValidationError`, etc.
- String values: `"ready"`, `"validationerror"`, etc. (case-insensitive)

All progress values are stored as lowercase strings in the database for consistency.

## Routing Logic

### Completed Progress
- Routes to `DefaultNextStage`
- Sets progress to `"ready"`
- Resets retry logic for the new stage

### Failed Progress
- If retries available: increments `RetryCount`, sets progress to `"ready"`, keeps current state
- If no retries left and `DefaultFailStage` defined: routes to fail stage
- If no retries left and no fail stage: item stays in current state with `"failed"` progress

### Other Progress Values
- **Ready, InProgress, Hold, ValidationError**: No routing action taken
- Item remains in current state with same progress

## Key Features

- **Case-insensitive state handling**: States like "Stage1", "STAGE1", and "stage1" are treated identically
- **Retry management**: Only the routing function modifies `RetryCount`
- **Worker separation**: Worker functions only update `Progress`, not `State` or `RetryCount`
- **Flexible schema**: Optional retry counts and fail stages per state
- **CosmosDB persistence**: All item state changes are automatically saved to CosmosDB
- **Dual ID support**: Items support both `id` (CosmosDB) and `ItemId` (legacy) properties

## Testing

```powershell
# Run basic tests
& .\test-module.ps1

# Run comprehensive tests
& .\test-module-comprehensive.ps1
```

## Example Workflow

```powershell
# 1. Create item
$item = New-RoutingItem -ItemId "workflow-1" -State "processing" -Progress "ready"

# 2. Process with worker
$item = Test-WorkerService -Item $item

# 3. Apply routing logic
$result = Invoke-RoutingBySchema -Item $item -RoutingSchema $schema

# 4. Check result
Write-Host "Action: $($result.Action), New State: $($result.NewState)"
```

## Integration Notes

- **CosmosDB Integration**: This module requires proper CosmosDB configuration and connectivity
- **Azure Dependencies**: Requires Azure Key Vault access for CosmosDB connection strings
- **Configuration Management**: Works with the global 12c configuration system
- **Orchestration Ready**: Designed for enterprise orchestration scenarios with persistent state
- **Extensible Workers**: Worker functions can be customized for specific processing requirements
- **Dynamic Schemas**: Routing schemas can be stored externally and loaded dynamically

## Error Handling

The module includes comprehensive error handling for CosmosDB operations:

- Connection failures are reported with detailed error messages
- Item not found scenarios are handled gracefully
- State validation ensures data integrity
- Retry logic prevents infinite loops in failure scenarios