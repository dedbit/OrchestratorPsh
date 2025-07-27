# OrchestratorRouting.TestHelpers.psm1
# Test helper functions for OrchestratorRouting module

# Ensure ProgressState enum is available
using module ./OrchestratorRouting.psm1

# Ensure Assert-ItemStructure and Update-ItemProgress are available from the main module
$mainModulePath = Join-Path $PSScriptRoot 'OrchestratorRouting.psm1'
Import-Module -Name $mainModulePath -Force

function Test-WorkerService {
    <#
    .SYNOPSIS
        Test function that simulates worker processing with configurable outcomes.
    .EXAMPLE
        Test-WorkerService -Item $item -SimulateSuccess
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [object]$Item,
        [Parameter(Mandatory = $false)]
        [switch]$SimulateFailure,
        [Parameter(Mandatory = $false)]
        [switch]$SimulateSuccess
    )
    $outcome = $null
    Assert-ItemStructure -Item $Item
    Update-ItemProgress -Item $Item -Progress ([ProgressState]::InProgress)
    Write-Host "Processing item '$($Item.id)' in state '$($Item.State)'" -ForegroundColor Cyan
    Start-Sleep -Milliseconds 100
    if ($SimulateFailure) {
        Update-ItemProgress -Item $Item -Progress ([ProgressState]::Failed)
        Write-Host "Worker service failed for item '$($Item.id)'" -ForegroundColor Red
        return $Item
    }
    if ($SimulateSuccess) {
        Update-ItemProgress -Item $Item -Progress ([ProgressState]::Completed)
        Write-Host "Worker service completed for item '$($Item.id)'" -ForegroundColor Green
        return $Item
    }
    $outcome = Get-Random -Minimum 1 -Maximum 4
    if ($outcome -eq 1) {
        Update-ItemProgress -Item $Item -Progress ([ProgressState]::Failed)
        Write-Host "Worker service failed for item '$($Item.id)'" -ForegroundColor Red
        return $Item
    }
    Update-ItemProgress -Item $Item -Progress ([ProgressState]::Completed)
    Write-Host "Worker service completed for item '$($Item.id)'" -ForegroundColor Green
    return $Item
}

function Enable-TestMode {
    [CmdletBinding()]
    param()
    Set-Variable -Name TestMode -Value $true -Scope Global
    if (-not (Get-Variable -Name TestItems -Scope Global -ErrorAction SilentlyContinue)) {
        Set-Variable -Name TestItems -Value @{} -Scope Global
    }
    # Always redefine in-memory mocks to shadow production functions
    function global:Get-12cItem {
        param([string]$Id, [string]$DatabaseName, [string]$ContainerName)
        if ($Global:TestItems.ContainsKey($Id)) {
            return $Global:TestItems[$Id]
        }
        return $null
    }
    function global:Set-12cItem {
        param([object]$Item, [string]$DatabaseName, [string]$ContainerName)
        $Global:TestItems[$Item.id] = $Item
        return $Item
    }
    function global:Remove-12cItem {
        param([string]$Id, [string]$DatabaseName, [string]$ContainerName)
        if ($Global:TestItems.ContainsKey($Id)) {
            $Global:TestItems.Remove($Id)
        }
    }
    function global:Invoke-12cCosmosDbSqlQuery {
        param([string]$SqlQuery, [hashtable]$Parameters, [string]$DatabaseName, [string]$ContainerName)
        $results = @()
        if ($SqlQuery -like "*WHERE c.State = @state*") {
            $state = $Parameters.state
            foreach ($item in $Global:TestItems.Values) {
                if ($item.State -eq $state) {
                    if ($SqlQuery -like "*AND c.Progress = @progress*") {
                        $progress = $Parameters.progress
                        if ($item.Progress -eq $progress) {
                            $results += $item
                        }
                    } else {
                        $results += $item
                    }
                }
            }
        } elseif ($SqlQuery -like "SELECT TOP*") {
            $count = 0
            $topValue = 100
            if ($SqlQuery -match "SELECT TOP (\d+)") {
                $topValue = [int]$matches[1]
            }
            foreach ($item in $Global:TestItems.Values) {
                if ($count -lt $topValue) {
                    $results += $item
                    $count++
                }
            }
        } else {
            $results = $Global:TestItems.Values
        }
        return $results
    }
    # Explicitly shadow production Set-12cItem and related wrappers
    function global:Invoke-Set12cItem {
        param([object]$Item)
        Set-12cItem -Item $Item -DatabaseName "OrchestratorDb" -ContainerName "Items"
    }
    function global:Invoke-Get12cItem {
        param([string]$Id)
        Get-12cItem -Id $Id -DatabaseName "OrchestratorDb" -ContainerName "Items"
    }
    function global:Invoke-Remove12cItem {
        param([string]$Id)
        Remove-12cItem -Id $Id -DatabaseName "OrchestratorDb" -ContainerName "Items"
    }
    Write-Verbose "Test mode enabled - using in-memory storage and mocks redefined"
}

function Disable-TestMode {
    [CmdletBinding()]
    param()
    $Global:TestMode = $false
    $Global:TestItems = @{}
    Write-Verbose "Test mode disabled - using CosmosDB storage"
}



Export-ModuleMember -Function Test-WorkerService, Enable-TestMode, Disable-TestMode, Get-12cItem, Set-12cItem, Remove-12cItem, Invoke-12cCosmosDbSqlQuery
