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
        # Use local config.json in the same directory as the script
        Join-Path -Path (Get-ScriptRoot) -ChildPath "config.json"
    }

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
