function FindAndStopProcess {
    [CmdletBinding()]
    param (
        [ValidateNotNullOrEmpty()]
        [Parameter(Mandatory)]
        [string]$ProjectName
    )

    ## Get procss
    $ProcessObj = Get-Process | Where-Object { $_.Name.Contains($ProjectName) }

    ## Kill procss
    if ($null -ne $ProcessObj) { 
        Stop-Process -Id $ProcessObj.Id -Force
    }
}
