param(
    [Parameter(Mandatory)]
    [string]$ModuleName
)

# Get all commands from the module
$commands = Get-Command -Module $ModuleName

if (-not $commands) {
    Write-Error "No commands found for module '$ModuleName'. Ensure the module is imported and the name is correct."
    exit 1
}

$outputFile = "${ModuleName}_Commands_Docs.txt"

$docs = foreach ($cmd in $commands) {
    $help = Get-Help $cmd.Name -Full | Out-String
    "# $($cmd.Name) [$($cmd.CommandType)]`n$help`n"
}

$docs | Set-Content -Path $outputFile -Encoding UTF8

Write-Host "Documentation for all commands in module '$ModuleName' has been written to $outputFile" -ForegroundColor Green
