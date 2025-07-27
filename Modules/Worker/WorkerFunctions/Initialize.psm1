function Invoke-Initialize {
    [CmdletBinding()]
    param([Parameter(Mandatory=$true)]$Item)
    Write-Host "Processing Initialize for item '$($Item.id)'" -ForegroundColor White
    Start-Sleep -Milliseconds 200
    Update-ItemProgress -Item $Item -Progress "Completed"
}

Export-ModuleMember -Function Invoke-Initialize
