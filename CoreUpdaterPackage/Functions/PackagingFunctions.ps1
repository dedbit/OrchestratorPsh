function Ensure-NuGetProvider {
    Write-Host "Checking NuGet PackageProvider..." -ForegroundColor Cyan
    
    # Check if NuGet provider is installed
    $nugetProvider = Get-PackageProvider -Name NuGet -ErrorAction SilentlyContinue
    if (-not $nugetProvider) {
        Write-Host "NuGet PackageProvider not found. Installing..." -ForegroundColor Yellow
        try {
            Install-PackageProvider -Name NuGet -Force -Scope CurrentUser -MinimumVersion 2.8.5.201
            Write-Host "NuGet PackageProvider installed successfully." -ForegroundColor Green
        } catch {
            Write-Error "Failed to install NuGet PackageProvider: $($_.Exception.Message)"
            throw
        }
    } else {
        Write-Host "NuGet PackageProvider is already installed (version: $($nugetProvider.Version))." -ForegroundColor Green
        
        # Check if it's a recent version
        if ([version]$nugetProvider.Version -lt [version]"2.8.5.201") {
            Write-Host "Updating NuGet PackageProvider to latest version..." -ForegroundColor Yellow
            try {
                Install-PackageProvider -Name NuGet -Force -Scope CurrentUser -MinimumVersion 2.8.5.201
                Write-Host "NuGet PackageProvider updated successfully." -ForegroundColor Green
            } catch {
                Write-Warning "Failed to update NuGet PackageProvider: $($_.Exception.Message)"
            }
        }
    }
    
    # Ensure PowerShell Gallery is trusted
    $psGallery = Get-PSRepository -Name PSGallery -ErrorAction SilentlyContinue
    if ($psGallery -and $psGallery.InstallationPolicy -ne 'Trusted') {
        Write-Host "Setting PowerShell Gallery as trusted..." -ForegroundColor Yellow
        try {
            Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
            Write-Host "PowerShell Gallery is now trusted." -ForegroundColor Green
        } catch {
            Write-Warning "Failed to set PowerShell Gallery as trusted: $($_.Exception.Message)"
        }
    }
}
