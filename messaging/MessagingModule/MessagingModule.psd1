# Module manifest for module 'MessagingModule'

@{
    # Script module or binary module file associated with this manifest
    RootModule = 'MessagingModule.psm1'
    
    # Version number of this module
    ModuleVersion = '1.0.61'
    
    # ID used to uniquely identify this module
    GUID = '4e211f77-cb00-4af0-9ffa-6b29aa5b4c1a'
    
    # Author of this module
    Author = 'OrchestratorPsh Team'
    
    # Company or vendor of this module
    CompanyName = '12C'
    
    # Copyright statement for this module
    Copyright = '(c) 2025 OrchestratorPsh. All rights reserved.'
    
    # Description of the functionality provided by this module
    Description = 'PowerShell module for messaging functionality in OrchestratorPsh'
    
    # Minimum version of the PowerShell engine required by this module
    PowerShellVersion = '5.1'
    
    # Functions to export from this module
    FunctionsToExport = @('Send-Message', 'Receive-Message')
    
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
            Tags = @('Messaging', 'OrchestratorPsh')
            
            # A URL to the license for this module
            # LicenseUri = ''
            
            # A URL to the main website for this project
            # ProjectUri = ''
            
            # ReleaseNotes of this module
            ReleaseNotes = 'Initial release with placeholder functionality.'
        }
    }
}



























