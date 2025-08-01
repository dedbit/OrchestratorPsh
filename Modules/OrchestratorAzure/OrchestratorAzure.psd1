#
# Module manifest for module 'OrchestratorAzure'
#
# Generated by: OrchestratorPsh Team
#
# Generated on: 5/23/2025
#

@{

# Script module or binary module file associated with this manifest.
RootModule = 'OrchestratorAzure.psm1'

# Version number of this module.
ModuleVersion = '0.1.1'

# ID used to uniquely identify this module
GUID = '7bb642e3-0a42-4690-8972-ef2d78a503b2'

# Author of this module
Author = 'OrchestratorPsh Team'

# Company or vendor of this module
CompanyName = '12C'

# Copyright statement for this module
Copyright = '(c) 2025 12C. All rights reserved.'

# Description of the functionality provided by this module
Description = 'Azure-related functions for OrchestratorPsh project'

# Minimum version of the PowerShell engine required by this module
PowerShellVersion = '5.1'

# Functions to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no functions to export.
FunctionsToExport = @('Get-12cKeyVaultSecret', 'Connect-12Azure', 'Connect-12AzureWithCertificate', 'Get-ServicePrincipalObjectId', 'Set-12cKeyVaultSecret')

# Cmdlets to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no cmdlets to export.
CmdletsToExport = @()

# Variables to export from this module
VariablesToExport = '*'

# Aliases to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no aliases to export.
AliasesToExport = @()

# Required modules to import as dependencies for this module
# RequiredModules = @('Packaging') # Removed - importing manually in the PSM1 file

}
