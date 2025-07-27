# TestAllAzureUser.ps1
# Runs all test scripts in subfolders, using pushd/popd for isolation. This focusses on scripts that require Azure User authentication.

$ErrorActionPreference = 'Stop'

$testScripts = @(
    @{ Path = "Modules/CosmosDB"; Script = "test-integration.ps1" },
    @{ Path = "Modules/CosmosDB"; Script = "test-integration3.ps1" },
    @{ Path = "Modules/OrchestratorRouting"; Script = "test-integration.ps1" },
    @{ Path = "Modules/Worker"; Script = "test-integration.ps1" }
)

foreach ($test in $testScripts) {
    $folder = $test.Path
    $script = $test.Script
    $fullPath = Join-Path $folder $script
    if (Test-Path $fullPath) {
        Write-Host "--- Running $script in $folder ---" -ForegroundColor Cyan
        pushd $folder
        try {
            & (".\" + $script)
            Write-Host "Test $script completed successfully." -ForegroundColor Green
        } catch {
            Write-Host "Test $script failed: $($_.Exception.Message)" -ForegroundColor Red
        } finally {
            popd
        }
    } else {
        Write-Host "Test script $fullPath not found, skipping." -ForegroundColor Yellow
    }
}

Write-Host "All test scripts processed." -ForegroundColor Cyan
