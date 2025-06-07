# install-local.ps1
# Script to install the Packaging module locally for development/testing

param(
    [Parameter(Mandatory=$false)]
    [string]$Scope = "CurrentUser", # CurrentUser or AllUsers
    
    [Parameter(Mandatory=$false)]
    [switch]$Force = $false
)

# --- Path Definitions ---
# Robust path construction
$scriptRootPath = ($PSScriptRoot ? $PSScriptRoot : (Get-Location).Path)

$NuspecFilePath = Join-Path -Path $scriptRootPath -ChildPath "Packaging.nuspec"
$OutputDirectory = Join-Path -Path $scriptRootPath -ChildPath "..\..\Output"

Write-Host "Installing Packaging module locally..." -ForegroundColor Cyan
Write-Host "Scope: $Scope" -ForegroundColor White
Write-Host "Force: $Force" -ForegroundColor White

# --- Module Imports ---
try {
    Import-Module (Join-Path -Path $scriptRootPath -ChildPath "Packaging.psd1") -Force
    Write-Host "Packaging module imported successfully." -ForegroundColor Green
} catch {
    Write-Error "Failed to import Packaging module: $($_.Exception.Message)"
    exit 1
}

# --- Main Script Execution ---
try {
    # 1. Get the current package version
    $currentVersion = Get-PackageVersionFromNuspec -NuspecPath $NuspecFilePath
    $packageFileName = "Packaging.$currentVersion.nupkg"
    $packagePath = Join-Path -Path $OutputDirectory -ChildPath $packageFileName
    
    Write-Host "Current package version: $currentVersion" -ForegroundColor Cyan
    Write-Host "Package file: $packagePath" -ForegroundColor White

    # 2. Verify package exists
    if (-not (Test-Path $packagePath)) {
        Write-Error "Package file not found: $packagePath. Please run build.ps1 first."
        exit 1
    }

    # 3. Determine the PowerShell modules path based on scope
    if ($Scope -eq "AllUsers") {
        $modulesPath = $env:ProgramFiles + "\PowerShell\Modules"
        if (-not $modulesPath -or -not (Test-Path $modulesPath)) {
            # Fallback for Windows PowerShell
            $modulesPath = $env:ProgramFiles + "\WindowsPowerShell\Modules"
        }
        # Cross-platform fallback for AllUsers
        if (-not $modulesPath -or -not (Test-Path (Split-Path $modulesPath))) {
            $modulesPath = "/usr/local/share/powershell/Modules"
        }
    } else {
        # CurrentUser scope
        $documentsPath = [System.Environment]::GetFolderPath('MyDocuments')
        if ($documentsPath) {
            $modulesPath = Join-Path $documentsPath "PowerShell\Modules"
            if (-not (Test-Path $modulesPath)) {
                # Fallback for Windows PowerShell
                $modulesPath = Join-Path $documentsPath "WindowsPowerShell\Modules"
            }
        } else {
            # Cross-platform fallback for CurrentUser when Documents path is not available
            $homeDir = if ($env:HOME) { $env:HOME } else { $env:USERPROFILE }
            $modulesPath = Join-Path $homeDir ".local/share/powershell/Modules"
        }
    }

    # 4. Create target directory
    $targetModulePath = Join-Path $modulesPath "Packaging\$currentVersion"
    Write-Host "Target installation path: $targetModulePath" -ForegroundColor White

    # 5. Check if module is already installed
    if ((Test-Path $targetModulePath) -and -not $Force) {
        Write-Host "Packaging module version $currentVersion is already installed at $targetModulePath" -ForegroundColor Yellow
        Write-Host "Use -Force to overwrite the existing installation." -ForegroundColor Yellow
        return
    }

    # 6. Extract package contents
    $tempPath = if ($env:TEMP) { $env:TEMP } elseif ($env:TMPDIR) { $env:TMPDIR } else { "/tmp" }
    $tempExtractPath = Join-Path $tempPath "PackagingModuleInstall"
    if (Test-Path $tempExtractPath) {
        Remove-Item $tempExtractPath -Recurse -Force
    }
    New-Item -ItemType Directory -Path $tempExtractPath -Force | Out-Null

    Write-Host "Extracting package contents..." -ForegroundColor Cyan
    
    # Use built-in .NET to extract the NuGet package (which is a ZIP file)
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    [System.IO.Compression.ZipFile]::ExtractToDirectory($packagePath, $tempExtractPath)

    # 7. Copy module files from extracted package
    $sourceToolsPath = Join-Path $tempExtractPath "tools"
    if (-not (Test-Path $sourceToolsPath)) {
        throw "Package structure is invalid. Expected 'tools' folder not found."
    }

    # Create target directory
    if (Test-Path $targetModulePath) {
        Remove-Item $targetModulePath -Recurse -Force
    }
    New-Item -ItemType Directory -Path $targetModulePath -Force | Out-Null

    # Copy all files from tools to target
    Copy-Item -Path "$sourceToolsPath\*" -Destination $targetModulePath -Recurse -Force

    Write-Host "Module files copied to: $targetModulePath" -ForegroundColor Green

    # 8. Clean up temporary files
    Remove-Item $tempExtractPath -Recurse -Force -ErrorAction SilentlyContinue

    # 9. Verify installation
    try {
        Remove-Module Packaging -ErrorAction SilentlyContinue
        Import-Module Packaging -Force
        Write-Host "Module installation verified successfully!" -ForegroundColor Green
        Write-Host "You can now use 'Import-Module Packaging' to use the installed module." -ForegroundColor Cyan
    } catch {
        Write-Warning "Module was installed but verification failed: $($_.Exception.Message)"
    }

} catch {
    Write-Error "An error occurred during the installation process: $($_.Exception.Message)"
    exit 1
}