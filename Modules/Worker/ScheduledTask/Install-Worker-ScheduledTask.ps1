# Install-Worker-ScheduledTask.ps1
# Script to create a scheduled task that runs the Worker module every 15 minutes starting at 5 minutes past the hour
# Based on CoreUpdaterPackage\ScheduledTask\Install-ScheduledTask.ps1

param(
    [string]$TaskName = "Run-Worker-Task",
    [string]$TaskDescription = "Automated task to run Worker module for batch processing of RoutingItems",
    [int]$StartMinute = 5,
    [int]$RepeatMinutes = 15,
    [switch]$RunInBackground,
    [switch]$SkipAdminCheck,
    [switch]$DryRun
)

# Check for administrator privileges (unless skipped)
if (-not $SkipAdminCheck) {
    if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        Write-Error "You are NOT running this script as Administrator. Creating scheduled tasks requires admin rights. Aborting script."
        exit 1
    }
}

# Define function to check if user has 'Log on as a batch job' right
function Test-LogonAsBatchJob {
    param([string]$UserName)
    try {
        $exportFile = "$env:TEMP\secpol.inf"
        secedit /export /cfg $exportFile 2>$null | Out-Null
        $batchLine = (Get-Content $exportFile) | Where-Object { $_ -match '^SeBatchLogonRight' }
        Remove-Item $exportFile -ErrorAction SilentlyContinue
        if (-not $batchLine) { return $false }
        $batchUsers = ($batchLine -split '=')[-1].Trim()
        if (-not $batchUsers) { return $false }
        $whoami = whoami
        $whoamiShort = $whoami -replace '^.*\\',''  # Get just the username part
        # Check if the username or the full whoami is in the batch users string
        if ($batchUsers -match $whoamiShort -or $batchUsers -match $whoami) {
            return $true
        } else {
            return $false
        }
    } catch {
        return $false
    }
}

# Import the helper module from CoreUpdaterPackage
$coreScheduledTaskPath = Join-Path ($PSScriptRoot ? $PSScriptRoot : (Get-Location).Path) "..\..\..\CoreUpdaterPackage\ScheduledTask\task-scheduler.ps1"
if (-not (Test-Path $coreScheduledTaskPath)) {
    Write-Error "Core scheduled task helper not found at $coreScheduledTaskPath. Please ensure CoreUpdaterPackage\ScheduledTask\task-scheduler.ps1 exists."
    exit 1
}
. $coreScheduledTaskPath

# Define paths using robust path construction pattern from the codebase
$scriptRootPath = $PSScriptRoot ? $PSScriptRoot : (Get-Location).Path
$batchFilePath = Join-Path $scriptRootPath "Run-Worker.bat"

# Validate that the batch file exists
if (-not (Test-Path $batchFilePath)) {
    Write-Error "Batch file not found at $batchFilePath. Please ensure Run-Worker.bat exists in the same directory."
    exit 1
}

Write-Host "Creating scheduled task '$TaskName'..." -ForegroundColor Cyan
Write-Host "Batch file path: $batchFilePath" -ForegroundColor Yellow
Write-Host "Task will run every $RepeatMinutes minutes starting at $StartMinute minutes past the hour" -ForegroundColor Yellow

# Prompt for credentials for the currently signed-in user
if ($IsWindows -or $env:OS -like "Windows*") {
    $currentUser = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
} else {
    # On non-Windows platforms, use a placeholder
    $currentUser = $env:USER ? $env:USER : "current-user"
}

# Check for batch logon right if running in background (after $currentUser is set)
if ($RunInBackground) {
    if (-not (Test-LogonAsBatchJob -UserName $currentUser)) {
        Write-Error "User '$currentUser' does not have 'Log on as a batch job' rights.`nTo fix: Open 'secpol.msc' > Local Policies > User Rights Assignment > Log on as a batch job, and add your user. Log off/on or reboot after change."
        exit 1
    }
}

# Set up parameters for CreateOrUpdateSchaduledTask
if ($RunInBackground) {
    $credential = Get-Credential -UserName $currentUser -Message "Enter the password for the user account to run the scheduled task."
    $params = @{
        TaskName = $TaskName
        TaskPath = "\12C\"
        SoftwarePath = $batchFilePath
        WorkingDirectory = $scriptRootPath
        ServiceAccountUsername = $credential.UserName
        ServiceAccountPassword = $credential.GetNetworkCredential().Password
    }
} else {
    $params = @{
        TaskName = $TaskName
        TaskPath = "\12C\"
        SoftwarePath = $batchFilePath
        WorkingDirectory = $scriptRootPath
    }
}

# Set the argument (empty for now, can be extended if needed)
$params.Argument = ''

# Set trigger for repeat every 15 minutes starting at 5 minutes past the hour
$params.TriggerKind = "Repeat"
$params.Interval = "PT${RepeatMinutes}M"  # ISO8601 duration for repeat interval

# Calculate start time: current hour + StartMinute minutes
$now = Get-Date
$startTime = Get-Date -Hour $now.Hour -Minute $StartMinute -Second 0 -Millisecond 0
if ($startTime -le $now) {
    # If the start time for this hour has passed, start in the next hour
    $startTime = $startTime.AddHours(1)
}
$params.StartTime = $startTime.ToString("HH:mm")

# Call the helper function
if ($DryRun) {
    Write-Host "Dry run: scheduled task parameters would be:" -ForegroundColor Cyan
    # Display the task creation parameters for verification
    $params | Format-List
    Write-Host "Calculated start time: $startTime" -ForegroundColor Yellow
    return
}

CreateOrUpdateSchaduledTask @params

Write-Host "✓ Scheduled task '$TaskName' created or updated successfully!" -ForegroundColor Green
Write-Host "Task details:" -ForegroundColor Cyan
Write-Host "  - Name: $TaskName" -ForegroundColor White
Write-Host "  - Description: $TaskDescription" -ForegroundColor White
Write-Host "  - Executable: $batchFilePath" -ForegroundColor White
Write-Host "  - Schedule: Every $RepeatMinutes minutes starting at $StartMinute minutes past the hour" -ForegroundColor White
Write-Host "  - Start time: $startTime" -ForegroundColor White
Write-Host "  - Run Level: Highest (Administrator)" -ForegroundColor White
Write-Host "  - User Account: $($currentUser)" -ForegroundColor White

Write-Host "`nYou can manage this task using:" -ForegroundColor Yellow
Write-Host "  - Task Scheduler GUI (taskschd.msc) - Look in the '12C' folder" -ForegroundColor White
Write-Host "  - PowerShell: Get-ScheduledTask -TaskName '$TaskName' -TaskPath '\12C\'" -ForegroundColor White
Write-Host "  - PowerShell: Start-ScheduledTask -TaskName '$TaskName' -TaskPath '\12C\' (to run immediately)" -ForegroundColor White
Write-Host "  - PowerShell: Unregister-ScheduledTask -TaskName '$TaskName' -TaskPath '\12C\' (to remove)" -ForegroundColor White

Write-Host "`nScheduled task installation completed." -ForegroundColor Green