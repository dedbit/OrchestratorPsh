# TestAll.ps1
# Runs all test scripts in subfolders, using pushd/popd for isolation

$ErrorActionPreference = 'Stop'

$testScripts = @(
    @{ Path = "CoreUpdaterPackage"; Script = "TestArtifactsFeed.ps1" },
    @{ Path = "messaging"; Script = "test-keyvault-fixed.ps1" },
    @{ Path = "messaging"; Script = "test-psrepository.ps1" },
    @{ Path = "Modules/Configuration"; Script = "Test-Module.ps1" },
    @{ Path = "Modules/Configuration"; Script = "Test-ModuleComprehensive.ps1" },
    @{ Path = "Modules/OrchestratorAzure"; Script = "Test-Module.ps1" },
    @{ Path = "Modules/OrchestratorCommon"; Script = "Test-Module.ps1" }
)

foreach ($test in $testScripts) {
    $folder = $test.Path
    $script = $test.Script
    $fullPath = Join-Path $folder $script
    if (Test-Path $fullPath) {
        Write-Host "\n--- Running $script in $folder ---" -ForegroundColor Cyan
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

Write-Host "\nAll test scripts processed." -ForegroundColor Cyan
