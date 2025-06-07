# CommonConnectionsPackage.psm1
# Module for managing connection details used across OrchestratorPsh scripts

# Global variable to store connection configuration
$Script:ConnectionConfig = $null

# Function to get connection details
function Get-12cConnection {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $false)]
        [string]$ConnectionName,
        
        [Parameter(Mandatory = $false)]
        [string]$ConfigFilePathOverride
    )

    # Load configuration if not already loaded or if override path is specified
    if ($null -eq $Script:ConnectionConfig -or $ConfigFilePathOverride) {
        $configFilePath = Get-ConnectionConfigPath -ConfigFilePathOverride $ConfigFilePathOverride
        $Script:ConnectionConfig = Import-ConnectionConfig -ConfigPath $configFilePath
    }

    # If no specific connection name is requested, return the Default connection
    if ([string]::IsNullOrEmpty($ConnectionName)) {
        # Try to get the Default connection from the Connections section
        if ($Script:ConnectionConfig.PSObject.Properties.Name -contains 'Connections' -and 
            $Script:ConnectionConfig.Connections.PSObject.Properties.Name -contains 'Default') {
            return $Script:ConnectionConfig.Connections.Default
        } else {
            # Fallback to returning all configuration for backward compatibility
            return $Script:ConnectionConfig
        }
    }

    # Return specific connection detail
    $connectionValue = $null
    try {
        # Use dot notation to access nested properties
        $connectionValue = Invoke-Expression "`$Script:ConnectionConfig.$ConnectionName"
    } catch {
        Write-Warning "Connection property '$ConnectionName' not found in configuration."
        return $null
    }

    return $connectionValue
}

# Helper function to determine configuration file path
function Get-ConnectionConfigPath {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $false)]
        [string]$ConfigFilePathOverride
    )

    # If override path is provided and exists, use it
    if (-not [string]::IsNullOrEmpty($ConfigFilePathOverride) -and (Test-Path -Path $ConfigFilePathOverride)) {
        return $ConfigFilePathOverride
    }

    # Determine the script root path (handles both script execution and direct terminal)
    $scriptRoot = if ($PSScriptRoot) { 
        $PSScriptRoot 
    } elseif ($PSCommandPath) { 
        Split-Path -Path $PSCommandPath -Parent 
    } else { 
        (Get-Location).Path 
    }

    # Build path to environments/dev.json - three levels up from CommonConnectionsPackage.psm1
    $configPath = Join-Path -Path $scriptRoot -ChildPath "..\..\..\environments\dev.json"
    return $configPath
}

# Helper function to import and parse connection configuration
function Import-ConnectionConfig {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$ConfigPath
    )

    try {
        # Check if the configuration file exists
        if (-not (Test-Path -Path $ConfigPath)) {
            throw "Configuration file not found at path: $ConfigPath"
        }

        # Load and parse the JSON configuration file
        $configContent = Get-Content -Path $ConfigPath -Raw | ConvertFrom-Json
        
        Write-Verbose "Connection configuration loaded successfully from: $ConfigPath"
        return $configContent
        
    } catch {
        Write-Error "Failed to load connection configuration: $($_.Exception.Message)"
        throw
    }
}

# Export the main function
Export-ModuleMember -Function Get-12cConnection