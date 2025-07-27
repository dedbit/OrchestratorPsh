# Install-ScheduledTask.ps1
# Script to create a scheduled task that runs Update-12cModules.bat in administrator mode
# This script creates a scheduled task to regularly update PowerShell modules

param(
    [string]$TaskName = "Update-12cModules-Task",
    [string]$TaskDescription = "Automated task to update 12C PowerShell modules using Update-12cModules.ps1",
    [string]$TriggerType = "Repeat",
    [string]$TriggerTime = "03:00",
    [ValidateSet(5,10,15,30,60)]
    [int]$RunEveryMinute = 30,
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


# Import the helper module
. "$PSScriptRoot\task-scheduler.ps1"

# Define paths using robust path construction pattern from the codebase
$scriptRootPath = $PSScriptRoot ? $PSScriptRoot : (Get-Location).Path
$batchFilePath = Join-Path $scriptRootPath "Update-12cModules.bat"

# Validate that the batch file exists
if (-not (Test-Path $batchFilePath)) {
    Write-Error "Batch file not found at $batchFilePath. Please ensure Update-12cModules.bat exists in the same directory."
    exit 1
}

Write-Host "Creating scheduled task '$TaskName'..." -ForegroundColor Cyan
Write-Host "Batch file path: $batchFilePath" -ForegroundColor Yellow
if ($TriggerType -eq "Repeat") {
    Write-Host "Task will run every $RunEveryMinute minutes" -ForegroundColor Yellow
} else {
    Write-Host "Task will run $TriggerType at $TriggerTime" -ForegroundColor Yellow
}

# Prompt for credentials for the currently signed-in user
$currentUser = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name

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
        TaskPath = "\12c\"
        SoftwarePath = $batchFilePath
        WorkingDirectory = $scriptRootPath
        ServiceAccountUsername = $credential.UserName
        ServiceAccountPassword = $credential.GetNetworkCredential().Password
    }
} else {
    $params = @{
        TaskName = $TaskName
        TaskPath = "\12c\"
        SoftwarePath = $batchFilePath
        WorkingDirectory = $scriptRootPath
    }
}

# If argument is provided, add it to params
if ($PSBoundParameters.ContainsKey('Argument')) {
    $params.Argument = $Argument
} else {
    $params.Argument = ''
}

# Set trigger kind and time
switch ($TriggerType.ToLower()) {
    "daily" {
        $params.TriggerKind = "Daily"
        $params.StartTime = $TriggerTime
    }
    "weekly" {
        $params.TriggerKind = "Weekly"
        $params.StartTime = $TriggerTime
        $params.DaysOfWeek = "Monday"
    }
    "startup" {
        $params.TriggerKind = "Daily"
        $params.StartTime = $TriggerTime
        Write-Warning "'Startup' trigger not directly supported; using Daily as fallback."
    }
    "repeat" {
        $params.TriggerKind = "Repeat"
        $params.Interval = "PT${RunEveryMinute}M"  # ISO8601 duration
    }
    default {
        $params.TriggerKind = "Daily"
        $params.StartTime = $TriggerTime
        Write-Warning "Unknown trigger type '$TriggerType'. Using daily trigger instead."
    }
}

# Call the helper function
if ($DryRun) {
    Write-Host "Dry run: scheduled task parameters would be:" -ForegroundColor Cyan
    # Display the task creation parameters for verification
    $params | Format-List
    return
}
CreateOrUpdateSchaduledTask @params

Write-Host "✓ Scheduled task '$TaskName' created or updated successfully!" -ForegroundColor Green
Write-Host "Task details:" -ForegroundColor Cyan
Write-Host "  - Name: $TaskName" -ForegroundColor White
Write-Host "  - Description: $TaskDescription" -ForegroundColor White
Write-Host "  - Executable: $batchFilePath" -ForegroundColor White
if ($TriggerType -eq "Repeat") {
    Write-Host "  - Schedule: Every 30 minutes" -ForegroundColor White
} else {
    Write-Host "  - Schedule: $TriggerType at $TriggerTime" -ForegroundColor White
}
Write-Host "  - Run Level: Highest (Administrator)" -ForegroundColor White
Write-Host "  - User Account: $($currentUser)" -ForegroundColor White

Write-Host "`nYou can manage this task using:" -ForegroundColor Yellow
Write-Host "  - Task Scheduler GUI (taskschd.msc) - Look in the '12c' folder" -ForegroundColor White
Write-Host "  - PowerShell: Get-ScheduledTask -TaskName '$TaskName' -TaskPath '\12c\'" -ForegroundColor White
Write-Host "  - PowerShell: Start-ScheduledTask -TaskName '$TaskName' -TaskPath '\12c\' (to run immediately)" -ForegroundColor White
Write-Host "  - PowerShell: Unregister-ScheduledTask -TaskName '$TaskName' -TaskPath '\12c\' (to remove)" -ForegroundColor White

Write-Host "`nScheduled task installation completed." -ForegroundColor Green    
Write-Host "  - Schedule: $TriggerType at $TriggerTime" -ForegroundColor White