# OrchestratorCommon.psm1
# This module serves as a wrapper/loader for the OrchestratorAzure module.
# It allows existing code to continue working with OrchestratorCommon imports
# without having to update all references.

# Get the path to the OrchestratorAzure module
$modulePath = Join-Path -Path $PSScriptRoot -ChildPath "..\OrchestratorAzure\OrchestratorAzure.psd1"

# Check if OrchestratorAzure module exists
if (-not (Test-Path $modulePath)) {
    $errorMessage = "OrchestratorAzure module not found at: $modulePath"
    Write-Error $errorMessage
    throw $errorMessage
}

# Import the OrchestratorAzure module
try {
    Import-Module -Name $modulePath -Global -Force
    Write-Verbose "OrchestratorAzure module imported successfully by OrchestratorCommon wrapper."
}
catch {
    $errorMessage = "Error importing OrchestratorAzure module: $($_.Exception.Message)"
    Write-Error $errorMessage
    throw $errorMessage
}

# Export all functions from the OrchestratorAzure module 
# This ensures that functions like Get-12cKeyVaultSecret and Connect-12Azure
# are available to any script that imports OrchestratorCommon
$functionsToExport = (Get-Command -Module OrchestratorAzure).Name
if ($functionsToExport) {
    Write-Verbose "Exporting functions from OrchestratorAzure: $($functionsToExport -join ', ')"
    Export-ModuleMember -Function $functionsToExport
} else {
    Write-Warning "No functions found in OrchestratorAzure module to export"
}
