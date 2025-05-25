# Configuration.psd1
# Module manifest for module 'Configuration'

@{
    # Script module or binary module file associated with this manifest
    RootModule = 'ConfigurationPackage.psm1'

    # Version number of this module
    ModuleVersion = '1.0.3'

    # ID used to uniquely identify this module
    GUID = '12345678-1234-1234-1234-123456789abc'

    # Author of this module
    Author = 'OrchestratorPsh Team'

    # Company or vendor of this module
    CompanyName = '12C'

    # Copyright statement for this module
    Copyright = '(c) 2025 OrchestratorPsh. All rights reserved.'

    # Description of the functionality provided by this module
    Description = 'Module for configuration-related functions in OrchestratorPsh'

    # Minimum version of the PowerShell engine required by this module
    PowerShellVersion = '5.1'

    # Functions to export from this module
    FunctionsToExport = @('Initialize-12Configuration', 'Get-PSCommandPath')

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
            Tags = @('Configuration', 'OrchestratorPsh')

            # A URL to the license for this module
            # LicenseUri = ''

            # A URL to the main website for this project
            # ProjectUri = ''

            # ReleaseNotes of this module
            ReleaseNotes = 'Initial release of the Configuration module.'
        }
    }
}
