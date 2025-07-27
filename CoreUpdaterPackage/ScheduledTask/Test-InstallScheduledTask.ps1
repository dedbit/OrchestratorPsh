# Test-InstallScheduledTask.ps1
# Test script to verify Install-ScheduledTask.ps1 creates the scheduled task with correct logon type

$ErrorActionPreference = 'Stop'

# Variables
$taskName = "Update-12cModules-Task"
$taskPath = "\12c\"
$installScript = Join-Path ($PSScriptRoot ? $PSScriptRoot : (Get-Location).Path) 'Install-ScheduledTask.ps1'

function Test-TaskLogonType {
    param(
        [string]$ExpectedType,
        [switch]$RunInBackground
    )
    # Remove the task if it already exists
    if (Get-ScheduledTask -TaskName $taskName -TaskPath $taskPath -ErrorAction SilentlyContinue) {
        Unregister-ScheduledTask -TaskName $taskName -TaskPath $taskPath -Confirm:$false
    }
    # Build script args using hashtable for named parameter splatting
    $params = @{ TaskName = $taskName }
    if ($RunInBackground) { $params.RunInBackground = $true }
    Write-Host ("Running Install-ScheduledTask.ps1 with params: " + ($params | Out-String)) -ForegroundColor Cyan
    & $installScript @params
    # Get the created task
    $task = Get-ScheduledTask -TaskName $taskName -TaskPath $taskPath -ErrorAction Stop
    # Check LogonType
    $logonType = $task.Principal.LogonType
    if ($logonType -ne $ExpectedType) {
        Write-Error "FAIL: LogonType is not '$ExpectedType'. Actual: $logonType"
        exit 1
    }
    Write-Host "PASS: Scheduled task '$taskName' exists and is set to '$ExpectedType'." -ForegroundColor Green
}

# Test Interactive (default)
Test-TaskLogonType -ExpectedType 'Interactive'
# Test Password (background)
Test-TaskLogonType -ExpectedType 'Password' -RunInBackground
