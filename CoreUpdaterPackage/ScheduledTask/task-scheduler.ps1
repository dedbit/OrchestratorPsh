function CreateOrUpdateSchaduledTask {
    [CmdletBinding()]
    param (
        [ValidateNotNullOrEmpty()]
        [Parameter(Mandatory)]
        [string]$TaskName,
        [ValidateNotNullOrEmpty()]
        [Parameter(Mandatory)]
        [string]$TaskPath,
        [ValidateNotNullOrEmpty()]
        [Parameter(Mandatory)]
        [string]$SoftwarePath,
        [Parameter(Mandatory)]
        [string]$WorkingDirectory,
        [Parameter(Mandatory=$false)]
        [string]$StartTime,
        [Parameter(Mandatory=$false)]
        [string]$TriggerKind,
        [Parameter(Mandatory=$false)]
        [string]$MonthsOfYear,
        [Parameter(Mandatory=$false)]
        [int[]]$DaysOfMonth,
        [Parameter(Mandatory=$false)]
        [string]$Argument,
        [Parameter(Mandatory=$false)]
        [string]$ServiceAccountUsername,
        [Parameter(Mandatory=$false)]
        [string]$ServiceAccountPassword,
        [Parameter(Mandatory=$false)]
        [string]$DaysOfWeek,
        [Parameter(Mandatory=$false)]
        [string]$Interval
    )

    $passwordLength = if ($ServiceAccountPassword) { $ServiceAccountPassword.Length } else { 0 }
    Write-Host "Function: CreateOrUpdateSchaduledTask; TaskName: $TaskName; TaskPath: $TaskPath; SoftwarePath: $SoftwarePath; WorkingDirectory: $WorkingDirectory; StartTime: $StartTime; TriggerKind: $TriggerKind; MonthsOfYear: $MonthsOfYear; DaysOfMonth: $DaysOfMonth; Argument: $Argument; ServiceAccountUsername: $ServiceAccountUsername; ServiceAccountPassword length: $passwordLength"

    ## Opret scheduled task action (bruges til Daily/Repeat - men ikke i Monthly)
    if ([string]::IsNullOrEmpty($Argument)) {
        $Action = New-ScheduledTaskAction -Execute $SoftwarePath -WorkingDirectory $WorkingDirectory
    } else {
        $Action = New-ScheduledTaskAction -Execute $SoftwarePath -Argument $Argument -WorkingDirectory $WorkingDirectory
    }

    if ($TriggerKind -eq "Monthly") {
        if (-not $StartTime) { throw "StartTime is required when TriggerKind is 'Monthly'" }
        if (-not $DaysOfMonth) { throw "DaysOfMonth is required when TriggerKind is 'Monthly'" }


        $existingTask = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
        $wasDisabled = $false
        if ($existingTask -and $existingTask.State -eq 'Disabled') {
            $wasDisabled = $true
        }

        if ($existingTask) {
            Write-Host "Task $TaskName already exists. Removing it before re-creating."
            Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
        }

        [DateTime]$parsed = [DateTime]::Parse($StartTime)
        $isoStart = $parsed.ToString("yyyy-MM-ddTHH:mm:ss")

        # If no ServiceAccountUsername provided, use current user
        if (-not $ServiceAccountUsername) {
            $ServiceAccountUsername = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
        }

        $xml = ConvertToMonthlyTaskXml `
            -TaskName $TaskName `
            -TaskPath $TaskPath `
            -SoftwarePath $SoftwarePath `
            -WorkingDirectory $WorkingDirectory `
            -DaysOfMonth $DaysOfMonth `
            -ServiceAccountUsername $ServiceAccountUsername `
            -StartBoundary $isoStart `
            -Argument $Argument

        if ($ServiceAccountPassword) {
            Register-ScheduledTask `
                -TaskName $TaskName `
                -TaskPath $TaskPath `
                -Xml $xml `
                -User $ServiceAccountUsername `
                -Password $ServiceAccountPassword `
                -Force
        } else {
            # Use current user without password (runs only when user is logged on)
            Register-ScheduledTask `
                -TaskName $TaskName `
                -TaskPath $TaskPath `
                -Xml $xml `
                -User $ServiceAccountUsername `
                -Force
        }

        Write-Host "SUCCESS: Scheduled task created/updated successfully (Monthly via XML)."

        # 8) Re-disable, hvis den var disabled
        if ($wasDisabled) {
            Write-Host "Task was previously disabled; disabling the newly created task."
            $newTask = Get-ScheduledTask -TaskName $TaskName
            Disable-ScheduledTask -InputObject $newTask
        }

        return # stop funktionen her
    }
    elseif ($TriggerKind -eq "Weekly") {
        # Kræv StartTime og DaysOfWeek
        if (-not $StartTime) { throw "StartTime is required when TriggerKind is 'Weekly'" }
        if (-not $DaysOfWeek) { throw "DaysOfWeek is required when TriggerKind is 'Weekly'" }

        Write-Host "Creating Weekly trigger ($DaysOfWeek) at $StartTime"

    
        $Trigger = New-ScheduledTaskTrigger -Weekly -DaysOfWeek $DaysOfWeek -At $StartTime
    }
    elseif ($TriggerKind -eq "Repeat") {
        # Repeat trigger every X minutes for one year
        $minutes = 30
        if ($PSBoundParameters.ContainsKey('Interval')) {
            if ($Interval -match '^PT(\d+)M$') { $minutes = [int]$Matches[1] }
        }
        $Interval = New-TimeSpan -Minutes $minutes
        $Duration = New-TimeSpan -Days 365
        $Trigger = New-ScheduledTaskTrigger -Once -At (Get-Date).Date.AddMinutes(1) -RepetitionInterval $Interval -RepetitionDuration $Duration
    }
    elseif ($TriggerKind -eq "Daily") {
        $Trigger = New-ScheduledTaskTrigger -Daily -At $StartTime
    } else {
        throw "TriggerKind must be provided"
    }

    # Herunder kører vi kun, hvis det er Daily eller Repeat

    $Settings = New-ScheduledTaskSettingsSet -MultipleInstances IgnoreNew

    # Tjek om tasken allerede eksisterer
    $Task = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue

    try {
        if ($null -ne $Task) {
            Write-Host "Task $TaskName already exists. Updating it."
            if ($ServiceAccountUsername -and $ServiceAccountPassword) {
                Set-ScheduledTask -TaskName $TaskName -TaskPath $TaskPath -Action $Action -Trigger $Trigger -Settings $Settings -User "$($ServiceAccountUsername)" -Password "$($ServiceAccountPassword)"
            } else {
                # Use current user without password (runs only when user is logged on)
                $currentUser = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
                Set-ScheduledTask -TaskName $TaskName -TaskPath $TaskPath -Action $Action -Trigger $Trigger -Settings $Settings -User $currentUser
            }
        } else {
            Write-Host "Creating new task $TaskName"
            if ($ServiceAccountUsername -and $ServiceAccountPassword) {
                Register-ScheduledTask -User "$($ServiceAccountUsername)" -Password "$($ServiceAccountPassword)" -TaskName $TaskName -TaskPath $TaskPath -Action $Action -Trigger $Trigger -Settings $Settings
            } else {
                # Use current user without password (runs only when user is logged on)
                $currentUser = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
                Register-ScheduledTask -User $currentUser -TaskName $TaskName -TaskPath $TaskPath -Action $Action -Trigger $Trigger -Settings $Settings
            }
        }

        # Hvis tasken var disabled før, disable den igen (hvis nødvendigt)
        if ($Task -and $Task.State -eq 'Disabled') {
            $Task = Get-ScheduledTask -TaskName $TaskName
            Disable-ScheduledTask -InputObject $Task
        }
    } catch {
        Write-Host "Failed to create/update task $TaskName $($_.Exception.Message)"
        throw $_
    }
}

##############################################################################
# Ny hjælpefunktion: ConvertToMonthlyTaskXml
##############################################################################
function ConvertToMonthlyTaskXml {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$TaskName,

        [Parameter(Mandatory=$true)]
        [string]$TaskPath,

        [Parameter(Mandatory=$true)]
        [string]$SoftwarePath,

        [Parameter(Mandatory=$true)]
        [string]$WorkingDirectory,

        [Parameter(Mandatory=$true)]
        [int[]]$DaysOfMonth,

        [Parameter(Mandatory=$true)]
        [string]$ServiceAccountUsername,

        [Parameter(Mandatory=$true)]
        [string]$StartBoundary,

        [Parameter(Mandatory=$false)]
        [string]$Argument
    )

    # Dynamisk generering af <Day> noder baseret på $DaysOfMonth
    $DaysXml = $DaysOfMonth | ForEach-Object {
        "<Day>$($_)</Day>"
    } | Out-String

    # Fjern eventuelle unødvendige linjeskift
    $DaysXml = $DaysXml.Trim()

    # Handle empty argument case for XML
    $ArgumentsXml = if ([string]::IsNullOrEmpty($Argument)) { "" } else { "<Arguments>$Argument</Arguments>" }

    # Sammensæt XML med de dynamisk genererede <Day>-noder
    $xml = @"
<?xml version="1.0" encoding="UTF-16"?>
<Task version="1.4" xmlns="http://schemas.microsoft.com/windows/2004/02/mit/task">
  <Triggers>
    <CalendarTrigger>
      <StartBoundary>$StartBoundary</StartBoundary>
      <Enabled>true</Enabled>
      <ScheduleByMonth>
        <DaysOfMonth>
          $DaysXml
        </DaysOfMonth>
      </ScheduleByMonth>
    </CalendarTrigger>
  </Triggers>
  <Principals>
    <Principal id="Author">
      <RunLevel>HighestAvailable</RunLevel>
      <UserId>$ServiceAccountUsername</UserId>
      <LogonType>Password</LogonType>
    </Principal>
  </Principals>
  <Actions>
    <Exec>
      <Command>$SoftwarePath</Command>
      $ArgumentsXml
      <WorkingDirectory>$WorkingDirectory</WorkingDirectory>
    </Exec>
  </Actions>
</Task>
"@

    return $xml
}

function StartSchaduledTask {
    [CmdletBinding()]
    param (
        [ValidateNotNullOrEmpty()]
        [Parameter(Mandatory)]
        [string]$TaskName,
        [ValidateNotNullOrEmpty()]
        [Parameter(Mandatory)]
        [string]$TaskPath
    )

    Write-Host "Function: StartSchaduledTask; TaskName: $TaskName; TaskPath: $TaskPath"
    Start-ScheduledTask -TaskName "$($TaskPath)\$($TaskName)"
}

function StopSchaduledTask {
    [CmdletBinding()]
    param (
        [ValidateNotNullOrEmpty()]
        [Parameter(Mandatory)]
        [string]$TaskName,
        [ValidateNotNullOrEmpty()]
        [Parameter(Mandatory)]
        [string]$TaskPath
    )

    Write-Host "Function: StopSchaduledTask; TaskName: $TaskName; TaskPath: $TaskPath"
    Stop-ScheduledTask -TaskName "$($TaskPath)\$($TaskName)" -ErrorAction SilentlyContinue
}

function StopAllInPathSchaduledTask {
    [CmdletBinding()]
    param (
        [ValidateNotNullOrEmpty()]
        [Parameter(Mandatory)]
        [string]$TaskPath
    )

    Write-Host "Function: StopAllInPathSchaduledTask; TaskPath: $TaskPath"
    Get-ScheduledTask -TaskPath "$($TaskPath)\" | Stop-ScheduledTask -ErrorAction SilentlyContinue
}

function RemoveSchaduledTask {
    [CmdletBinding()]
    param (
        [ValidateNotNullOrEmpty()]
        [Parameter(Mandatory)]
        [string]$TaskName
    )

    Write-Host "Function: RemoveSchaduledTask; TaskName: $TaskName"
    Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
}
