function Get-ScriptRoot {
    if ($PSScriptRoot) {
        return $PSScriptRoot
    } else {
        return (Get-Location).Path
    }
}
