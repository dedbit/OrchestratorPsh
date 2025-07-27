# CosmosDBPackage.psd1
# Module manifest for module 'CosmosDBPackage'

@{
    # Script module or binary module file associated with this manifest
    RootModule = 'CosmosDBPackage.psm1'

    # Version number of this module
    ModuleVersion = '1.0.15'

    # ID used to uniquely identify this module
    GUID = 'a1b2c3d4-e5f6-7890-abcd-ef1234567890'

    # Author of this module
    Author = 'OrchestratorPsh Team'

    # Company or vendor of this module
    CompanyName = '12C'

    # Copyright statement for this module
    Copyright = '(c) 2025 OrchestratorPsh. All rights reserved.'

    # Description of the functionality provided by this module
    Description = 'Module for CosmosDB operations in OrchestratorPsh'

    # Minimum version of the PowerShell engine required by this module
    PowerShellVersion = '5.1'

    # Required modules
    RequiredModules = @()

    # Functions to export from this module
    FunctionsToExport = @('Get-12cItem', 'Set-12cItem', 'Get-12cCosmosConnection','Remove-12cItem', 'Invoke-12cCosmosDbSqlQuery')

    # Cmdlets to export from this module
    CmdletsToExport = @()

    # Variables to export from this module
    VariablesToExport = @()

    # Aliases to export from this module
    AliasesToExport = @()

    # Private data to pass to the module specified in RootModule/ModuleToProcess
    PrivateData = @{
        PSData = @{
            # Tags applied to this module
            Tags = @('CosmosDB', 'OrchestratorPsh', 'Azure', 'Database')

            # A URL to the license for this module
            # LicenseUri = ''

            # A URL to the main website for this project
            # ProjectUri = ''

            # ReleaseNotes of this module
            ReleaseNotes = 'Initial release of the CosmosDB module.'
        }
    }
}














