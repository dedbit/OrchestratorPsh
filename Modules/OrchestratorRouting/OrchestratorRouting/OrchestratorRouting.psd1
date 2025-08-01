#
# Module manifest for module 'OrchestratorRouting'
#
# Generated by: OrchestratorPsh Team
#
# Generated on: 1/20/2025
#

@{

# Script module or binary module file associated with this manifest.
RootModule = 'OrchestratorRouting.psm1'

# Version number of this module.
ModuleVersion = '1.0.8'

# ID used to uniquely identify this module
GUID = 'a1b2c3d4-e5f6-7890-a1b2-c3d4e5f67890'

# Author of this module
Author = 'OrchestratorPsh Team'

# Company or vendor of this module
CompanyName = '12C'

# Copyright statement for this module
Copyright = '(c) 2025 12C. All rights reserved.'

# Description of the functionality provided by this module
Description = 'Orchestrator Routing module for item processing with progress and retry handling'

# Minimum version of the PowerShell engine required by this module
PowerShellVersion = '5.1'

# Required modules
RequiredModules = @()

# Functions to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no functions to export.
FunctionsToExport = @('Invoke-RoutingBySchema', 'Move-State', 'Update-ItemProgress', 'Get-RoutingItem', 'New-RoutingItem', 'Get-RoutingItemsByState', 'Get-RoutingItemsAll', 'Assert-ItemStructure')

# Cmdlets to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no cmdlets to export.
CmdletsToExport = @()

# Variables to export from this module
VariablesToExport = '*'

# Aliases to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no aliases to export.
AliasesToExport = @()

}











