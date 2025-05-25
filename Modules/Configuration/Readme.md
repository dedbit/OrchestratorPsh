# Install Configuration module for all users

# Setup local feed

# Register local NuGet repository (run once)
Register-PSRepository -Name LocalNuget -SourceLocation "$PWD\Output" -InstallationPolicy Trusted
# Install the Configuration package for all users
Install-Module -Name ConfigurationPackage -Scope AllUsers -Repository LocalNuget -Force

"$($pwd)\output"





```powershell
# Option 1: Install from local NuGet package (recommended for built packages)
Install-Module -Name ConfigurationPackage -Scope AllUsers -Repository LocalNuget -Force -SourcePath ..\..\Output

# Option 2: Manually copy to system modules folder
Copy-Item -Recurse -Force .\Modules\Configuration "C:\Program Files\PowerShell\Modules\Configuration"

# Option 3: Import directly from source (for development)
Import-Module .\Modules\Configuration\Configuration.psd1 -Force
```

# Import new version
Remove-Module Configuration
Import-Module Configuration
Get-Command -Module Configuration


# package management
Find-Module -Name ConfigurationPackage -Repository LocalNuget
Install-Module -Name ConfigurationPackage -Scope AllUsers -Repository LocalNuget -Force
