# Test-Connect-12AzureWithCertificate.ps1
# This script tests the Connect-12AzureWithCertificate function in a separate PowerShell session.
# It assumes that $global:12cConfig is already initialized in the environment.

$modulePath = Join-Path $PSScriptRoot '..' '..' 'Modules' 'OrchestratorAzure' 'OrchestratorAzure.psm1'

# Start a new PowerShell process to ensure a clean environment
$testScript = @'
try {
    # Load configuration before running the test
    $configModulePath = Join-Path $PSScriptRoot ".." ".." "Modules" "Configuration" "ConfigurationPackage.psd1"
    Import-Module -Name $configModulePath -Force
    Initialize-12Configuration

    Import-Module -Name $env:MODULE_PATH -Force
    $result = Connect-12AzureWithCertificate
    if ($result) {
        Write-Host "Connect-12AzureWithCertificate succeeded." -ForegroundColor Green
        # Try to get the PAT secret from Key Vault
        $config = $global:12cConfig
        $KeyVaultName = $config.keyVaultName
        $SecretName = "PAT"
        $secret = Get-AzKeyVaultSecret -VaultName $KeyVaultName -Name $SecretName -ErrorAction Stop
        if ($secret -and $secret.SecretValue) {
            $plain = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($secret.SecretValue))
            $masked = $plain.Substring(0, [Math]::Min(4, $plain.Length)) + "..."
            Write-Host "Successfully retrieved PAT secret from Key Vault. Value (masked): $masked" -ForegroundColor Green
            exit 0
        } else {
            Write-Host "Failed to retrieve PAT secret from Key Vault." -ForegroundColor Yellow
            exit 2
        }
    } else {
        Write-Host "Connect-12AzureWithCertificate returned a falsy value." -ForegroundColor Yellow
        exit 2
    }
} catch {
    Write-Host "Connect-12AzureWithCertificate or Key Vault access failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
'@

$testFile = Join-Path $PSScriptRoot 'Test-Connect-12AzureWithCertificate-Session.ps1'
Set-Content -Path $testFile -Value $testScript

# Set environment variable for the child process
$env:MODULE_PATH = $modulePath

# Run the test in a new PowerShell process
Write-Host "Running Connect-12AzureWithCertificate test in a new session..." -ForegroundColor Cyan
$psi = New-Object System.Diagnostics.ProcessStartInfo
$psi.FileName = 'pwsh.exe'
$psi.Arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$testFile`""
$psi.UseShellExecute = $false
$psi.RedirectStandardOutput = $true
$psi.RedirectStandardError = $true
$psi.EnvironmentVariables["MODULE_PATH"] = $modulePath
$process = [System.Diagnostics.Process]::Start($psi)
$stdout = $process.StandardOutput.ReadToEnd()
$stderr = $process.StandardError.ReadToEnd()
$process.WaitForExit()

Write-Host $stdout
if ($stderr) { Write-Host $stderr -ForegroundColor Red }

if ($process.ExitCode -eq 0) {
    Write-Host "Test PASSED." -ForegroundColor Green
} elseif ($process.ExitCode -eq 2) {
    Write-Host "Test completed but function returned a falsy value." -ForegroundColor Yellow
} else {
    Write-Host "Test FAILED." -ForegroundColor Red
}

# Clean up
Remove-Item $testFile -Force
