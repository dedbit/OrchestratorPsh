@{
    # Script module or binary module file associated with this manifest.
    RootModule = 'Packaging.psm1'

    # Version number of this module.
    ModuleVersion = '1.0.27'

    # ID used to uniquely identify this module
    GUID = '42f80e65-ae99-424e-9d8b-aa9a7d25df39' # Replaced New-Guid with a static GUID

    # Author of this module
    Author = 'GitHub Copilot'

    # Company or vendor of this module
    CompanyName = 'Unknown'

    # Copyright statement for this module
    Copyright = '(c) GitHub Copilot. All rights reserved.'

    # Description of the functionality provided by this module.
    Description = 'PowerShell module for common packaging and publishing tasks, including NuGet operations.'

    # Minimum version of the PowerShell engine required by this module
    # PowerShellVersion = ''

    # Name of the PowerShell host required by this module
    # PowerShellHostName = ''

    # Minimum version of the PowerShell host required by this module
    # PowerShellHostVersion = ''

    # Minimum version of Microsoft .NET Framework required by this module
    # DotNetFrameworkVersion = ''

    # Minimum version of the common language runtime (CLR) required by this module
    # CLRVersion = ''

    # Processor architecture (None, X86, Amd64) required by this module
    # ProcessorArchitecture = ''

    # Modules that must be imported into the global environment prior to importing this module
    # RequiredModules = @()

    # Assemblies that must be loaded prior to importing this module
    # RequiredAssemblies = @()

    # Script files (.ps1) that are run in the caller's session state when the module is imported
    # ScriptsToProcess = @()

    # Type files (.ps1xml) to be loaded when importing this module
    # TypesToProcess = @()

    # Format files (.ps1xml) to be loaded when importing this module
    # FormatsToProcess = @()

    # Modules to import as nested modules of the module specified in RootModule/ModuleToProcess
    # NestedModules = @()

    # Functions to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no functions to export.
    FunctionsToExport = @(
        'Get-PackageVersionFromNuspec',
        'Publish-NuGetPackageAndCleanup',
        'Ensure-NuGetFeedConfigured',
        'Confirm-DirectoryExists',        # Added
        'Set-PackageVersionIncrement',  # Added
        'Invoke-NuGetPack',             # Added
        'Remove-OldPackageVersions'     # Added
    )

    # Cmdlets to export from this module
    CmdletsToExport = @()

    # Variables to export from this module
    VariablesToExport = '*'

    # Aliases to export from this module
    AliasesToExport = @()

    # List of all modules packaged with this module
    # ModuleList = @()

    # List of all files packaged with this module
    # FileList = @()

    # Private data to pass to the module specified in RootModule/ModuleToProcess. This may also contain a PSData hashtable with additional module metadata used by PowerShell.
    PrivateData = @{

        PSData = @{
            # Tags applied to this module. These help with module discovery in online galleries.
            # Tags = @()

            # A URL to the license for this module.
            # LicenseUri = ''

            # A URL to the main website for this project.
            # ProjectUri = ''

            # A URL to an icon representing this module.
            # IconUri = ''

            # ReleaseNotes of this module
            # ReleaseNotes = ''
        }
    }

    # HelpInfo URI of this module
    # HelpInfoURI = ''

    # Default prefix for commands exported from this module. Override a command prefix using the Export-ModuleMember cmdlet. Default is to export all commands with no prefix.
    # DefaultCommandPrefix = ''
}




























