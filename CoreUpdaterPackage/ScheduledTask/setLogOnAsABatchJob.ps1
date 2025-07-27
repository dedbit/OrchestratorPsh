# This script should work on windows 10 home edition. Use secedit adding 'log on as a batch job' right to current user.

# Get current username and SID
$user = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
$sid = (New-Object System.Security.Principal.NTAccount($user)).Translate([System.Security.Principal.SecurityIdentifier]).Value

# Paths
$tempInf = "$env:TEMP\grant-batch.inf"
$dbPath = "$env:TEMP\secedit-batch.db"

# Create INF content as array to avoid here-string/interpolation issues
$infLines = @(
    '[Unicode]'
    'Unicode=yes'
    ''
    '[Version]'
    'signature="$CHICAGO$"'
    ''
    '[Privilege Rights]'
    "SeBatchLogonRight = $sid"
)

# Write to file (force ASCII, no BOM, correct line endings)
[System.IO.File]::WriteAllLines($tempInf, $infLines, [System.Text.Encoding]::ASCII)

# Debug: print file contents
if (Test-Path $tempInf) {
    Write-Host "INF file contents:" -ForegroundColor Yellow
    Get-Content $tempInf | ForEach-Object { Write-Host $_ }
} else {
    Write-Error "Failed to create INF file at $tempInf"
    exit 1
}

# Apply policy
secedit /configure /db $dbPath /cfg $tempInf /areas USER_RIGHTS

# Clean up
# Remove-Item $tempInf

# Refresh group policy to apply changes
Write-Host "Refreshing group policy..." -ForegroundColor Yellow
gpupdate /force | Out-Null
# whoami /priv

# Verify SeBatchLogonRight assignment using whoami /priv
Write-Host "Verifying 'Log on as a batch job' (SeBatchLogonRight) assignment using whoami /priv..." -ForegroundColor Cyan
$whoamiPriv = whoami /priv | Select-String -Pattern "SeBatchLogonRight" -SimpleMatch
if ($whoamiPriv) {
    Write-Host "✓ SeBatchLogonRight is present in whoami /priv output for $user" -ForegroundColor Green
} else {
    Write-Warning "✗ SeBatchLogonRight is NOT present in whoami /priv output for $user. You may need to log off and log on again for the permission to take effect."
}

# Registry-based assignment for Windows Home edition
Write-Host "Attempting registry-based assignment of SeBatchLogonRight..." -ForegroundColor Yellow
$lsaPath = 'HKLM:\SYSTEM\CurrentControlSet\Control\Lsa'
$regValue = 'SeBatchLogonRight'
$adminsSID = 'S-1-5-32-544'  # Built-in Administrators group

# Get current value (may not exist)
$current = try { 
    $regType = (Get-Item -Path $lsaPath).GetValueKind($regValue)
    $value = (Get-ItemProperty -Path $lsaPath -Name $regValue -ErrorAction Stop).$regValue
    if ($regType -eq 'String') {
        # Convert single string to array
        @($value)
    } else {
        $value
    }
} catch { @() }

if ($null -eq $current) { $current = @() }
if ($current -is [string]) { $current = @($current) }

# Ensure Administrators group SID is included (required for Windows Home)
if ($current -notcontains $adminsSID) {
    $current += $adminsSID
    Write-Host "Added Administrators group SID to SeBatchLogonRight" -ForegroundColor Cyan
}

if ($current -contains $sid) {
    Write-Host "✓ SID already present in SeBatchLogonRight registry value." -ForegroundColor Green
} else {
    $current += $sid
    Write-Host "✓ SID $sid added to SeBatchLogonRight registry value." -ForegroundColor Green
}

# Force write as REG_MULTI_SZ using reg.exe command
try {
    # Delete existing value first
    reg delete "HKLM\SYSTEM\CurrentControlSet\Control\Lsa" /v $regValue /f | Out-Null
    
    # Create multi-string value with both SIDs
    $multiValue = ($current -join "`0") + "`0"  # Null-separated with double-null terminator
    $regCommand = "reg add `"HKLM\SYSTEM\CurrentControlSet\Control\Lsa`" /v $regValue /t REG_MULTI_SZ /d `"$($current -join '\0')`" /f"
    
    # Use direct reg.exe with hex encoding for proper multi-string
    $hexData = ($current | ForEach-Object { [System.Text.Encoding]::Unicode.GetBytes($_ + "`0") }) -join ""
    $hexData += "00,00"  # Double null terminator
    
    reg add "HKLM\SYSTEM\CurrentControlSet\Control\Lsa" /v $regValue /t REG_MULTI_SZ /d ($current -join "`0") /f
    
    Write-Host "✓ Registry value written as REG_MULTI_SZ using reg.exe" -ForegroundColor Green
} catch {
    Write-Error "Failed to write registry value with reg.exe: $($_.Exception.Message)"
}

Write-Host "You must reboot for the change to take effect." -ForegroundColor Yellow