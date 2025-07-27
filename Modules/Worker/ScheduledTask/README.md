# Worker Scheduled Task

This directory contains scripts for setting up and managing a scheduled task for the Worker module.

## Files

- **Run-Worker.ps1** - Main script that loads the Worker module and executes `Invoke-Worker`
- **Run-Worker.bat** - Batch wrapper that calls the PowerShell script with proper logging
- **Install-Worker-ScheduledTask.ps1** - Script to create the scheduled task with specific timing requirements
- **Test-Install-Worker-ScheduledTask.ps1** - Test script to validate the scheduled task functionality

## Usage

### Manual Execution
```powershell
# Run the worker manually
.\Run-Worker.ps1

# Run with custom stages
.\Run-Worker.ps1 -Stages @("Initialize", "Upload")
```

### Install Scheduled Task
```powershell
# Install the scheduled task (requires administrator privileges)
.\Install-Worker-ScheduledTask.ps1

# Dry run to see what would be created
.\Install-Worker-ScheduledTask.ps1 -DryRun -SkipAdminCheck

# Install for background execution
.\Install-Worker-ScheduledTask.ps1 -RunInBackground
```

### Test the Implementation
```powershell
# Run all tests
.\Test-Install-Worker-ScheduledTask.ps1
```

## Scheduled Task Configuration

The scheduled task is configured to:
- Run every 15 minutes starting at 5 minutes past the hour
- Execute the Worker module with default stages (Initialize, SetReadOnly, Upload)
- Log output to `Run-Worker.log` in the same directory
- Run with highest privileges (Administrator)
- Be placed in the `\12C\` task folder

## Schedule Details

- **Start Time**: 5 minutes past the current hour (e.g., if installed at 2:30 PM, first run at 3:05 PM)
- **Repeat Interval**: Every 15 minutes (PT15M in ISO8601 format)
- **Duration**: Repeats for 1 year, then can be renewed

This means the task will run at:
- :05, :20, :35, :50 minutes of every hour
- For example: 9:05, 9:20, 9:35, 9:50, 10:05, 10:20, etc.

## Dependencies

- Worker module must be available at `../Worker/Worker.psd1`
- CoreUpdaterPackage scheduled task helpers at `../../../CoreUpdaterPackage/ScheduledTask/task-scheduler.ps1`
- PowerShell 5.1 or later (PowerShell 7 preferred)