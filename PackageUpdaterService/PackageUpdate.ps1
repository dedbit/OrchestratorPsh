# PackageUpdater.ps1

# Import necessary modules
Import-Module -Name Az.Accounts
Import-Module -Name Az.Artifacts

# Configuration
$ArtifactFeedUrl = "https://dev.azure.com/YourOrganization/_packaging/YourFeedName/nuget/v3/index.json"
$LocalPackagePath = "C:\Packages"
$CheckIntervalMinutes = 10

# Add a new parameter for the package name to monitor
$PackageName = "YourPackageName"  # Replace with the actual package name to monitor

# Update the log file path to use the script location
$ScriptDirectory = Split-Path -Parent $MyInvocation.MyCommand.Definition
$LogFilePath = Join-Path -Path $ScriptDirectory -ChildPath "PackageUpdater.log"

# Function to log messages
function Log-Message {
    param (
        [string]$Message
    )

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "$timestamp - $Message"
    Add-Content -Path $LogFilePath -Value $logEntry
    Write-Host $Message
}

# Update the Check-NewPackageVersion function to fetch the latest version from the artifacts feed
function Check-NewPackageVersion {
    param (
        [string]$FeedUrl,
        [string]$LocalPath,
        [string]$PackageName
    )

    Log-Message "Checking for new version of package: $PackageName..."

    # Fetch the latest version from the artifacts feed
    try {
        $latestVersion = (Invoke-RestMethod -Uri "$FeedUrl/$PackageName/index.json" -Method Get).versions[-1]
        Log-Message "Latest version of $PackageName from feed: $latestVersion"
    } catch {
        Log-Message "Error fetching latest version for $PackageName: $_"
        return $false
    }

    # Simulate fetching the local version (replace with actual logic)
    $localVersion = "1.0.0"   # Replace with actual local version check for $PackageName

    if ($latestVersion -ne $localVersion) {
        Log-Message "New version available for $PackageName: $latestVersion"
        return $true
    } else {
        Log-Message "No new version found for $PackageName."
        return $false
    }
}

# Update the Install-Package function to consider the package name
function Install-Package {
    param (
        [string]$FeedUrl,
        [string]$LocalPath,
        [string]$PackageName
    )

    Log-Message "Downloading and installing package: $PackageName..."

    try {
        # Simulate package download and installation for the specific package
        # Replace with actual download and installation logic for $PackageName
        Start-Sleep -Seconds 5
        Log-Message "$PackageName installed successfully."
    } catch {
        Log-Message "Error during installation of $PackageName: $_"
        Rollback-Package -PackageName $PackageName
    }
}

# Update the Rollback-Package function to consider the package name
function Rollback-Package {
    param (
        [string]$PackageName
    )

    Log-Message "Rolling back to the previous version of $PackageName..."
    # Simulate rollback logic for the specific package
    Start-Sleep -Seconds 3
    Log-Message "Rollback completed for $PackageName."
}

# Function to monitor system health
function Monitor-Health {
    Log-Message "Performing health check..."
    # Simulate health check logic
    $healthStatus = "Healthy"  # Replace with actual health check logic
    Log-Message "System health status: $healthStatus"
}

# Update the main loop to pass the package name
while ($true) {
    Monitor-Health

    if (Check-NewPackageVersion -FeedUrl $ArtifactFeedUrl -LocalPath $LocalPackagePath -PackageName $PackageName) {
        Install-Package -FeedUrl $ArtifactFeedUrl -LocalPath $LocalPackagePath -PackageName $PackageName
    }

    Log-Message "Waiting for $CheckIntervalMinutes minutes before next check..."
    Start-Sleep -Seconds ($CheckIntervalMinutes * 60)
}