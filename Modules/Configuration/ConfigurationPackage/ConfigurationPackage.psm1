# Configuration.psm1
# Module for configuration-related functions used across OrchestratorPsh scripts

# Function to connect to 12Configuration
function Initialize-12Configuration {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $false)]
        [string]$ConfigFilePathOverride
    )

    # Determine the configuration file path
    $configFilePath = if ($null -ne $ConfigFilePathOverride -and (Test-Path -Path $ConfigFilePathOverride)) {
        $ConfigFilePathOverride
    } else {
        # Adjusted path: environments is two levels up from ConfigurationPackage.psm1
        Join-Path -Path (Split-Path -Path (Get-PSCommandPath) -Parent) -ChildPath "..\..\..\environments\dev.json"
    }
    # ls $configFilePath

    try {
        # Check if the configuration file exists
        if (-Not (Test-Path -Path $configFilePath)) {
            throw "Configuration file not found at path: $configFilePath"
        }

        # Load the configuration file
        $configContent = Get-Content -Path $configFilePath -Raw | ConvertFrom-Json

        # Store the configuration in a global variable
        $Global:12cConfig = $configContent

        Write-Host "Configuration loaded successfully from $configFilePath and stored in global variable." -ForegroundColor Green
    } catch {
        Write-Error "Failed to load configuration: $($_.Exception.Message)"
        throw  # Stop execution if config fails to load
    }
    
    # After try/catch, ensure config is set
    if (-not $Global:12cConfig) {
        Write-Error "12cConfig is not set after attempting to load configuration. Aborting."
        throw "12cConfig is not set after attempting to load configuration."
    }
}

# Function to get the PowerShell command path, compatible with both scripts and terminal
function Get-PSCommandPath {
    [CmdletBinding()]
    param ()

    try {
        # Determine the command path
        if ( -not [string]::IsNullOrEmpty($PSCommandPath)) {
            # If running in a script, use $PSCommandPath
            return $PSCommandPath
        } else {
            # If running in a terminal, use the current location
            return (Get-Location).Path
        }
    } catch {
        Write-Error "Failed to determine the PowerShell command path: $($_.Exception.Message)"
        throw
    }
}

# Export the functions
Export-ModuleMember -Function Initialize-12Configuration, Get-PSCommandPath
