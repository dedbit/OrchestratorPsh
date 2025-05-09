# Check if NuGet is installed
if (-not (Get-Command nuget -ErrorAction SilentlyContinue)) {
    Write-Host "NuGet is not installed. Downloading NuGet..."

    # Define the download URL and destination path
    $nugetUrl = "https://dist.nuget.org/win-x86-commandline/latest/nuget.exe"
    $nugetPath = "C:\Windows\System32\nuget.exe"

    # Download NuGet
    Invoke-WebRequest -Uri $nugetUrl -OutFile $nugetPath -UseBasicParsing

    # Verify installation
    if (Test-Path $nugetPath) {
        Write-Host "NuGet has been successfully installed at $nugetPath."
    } else {
        Write-Error "Failed to install NuGet. Please check your permissions and try again."
    }
} else {
    Write-Host "NuGet is already installed."
}