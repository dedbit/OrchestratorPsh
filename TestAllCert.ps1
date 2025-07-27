# TestAllCert.ps1
# Runs all test scripts in subfolders, using pushd/popd for isolation. This focuses on scripts that require certificate authentication.

$ErrorActionPreference = 'Stop'

$testScripts = @(
    @{ Path = "CoreUpdaterPackage"; Script = "test-artifacts-feed.ps1" },
    @{ Path = "CoreUpdaterPackage"; Script = "test-self-contained.ps1" },
    @{ Path = "CoreUpdaterPackage"; Script = "test-module-update-fixes.ps1" },
    @{ Path = "Modules/MessagingModule"; Script = "test-keyvault-fixed.ps1" },
    @{ Path = "Modules/MessagingModule"; Script = "test-psrepository.ps1" },
    @{ Path = "Modules/Configuration"; Script = "test-module.ps1" },
    @{ Path = "Modules/Configuration"; Script = "test-module-comprehensive.ps1" },
    @{ Path = "Modules/CommonConnections"; Script = "test-module.ps1" },
    @{ Path = "Modules/CommonConnections"; Script = "test-module-comprehensive.ps1" },
    @{ Path = "Modules/CosmosDB"; Script = "test-module.ps1" },
    @{ Path = "Modules/CosmosDB"; Script = "test-module-comprehensive.ps1" },
    @{ Path = "Modules/CosmosDB"; Script = "test-cosmos-api-demo.ps1" },
    @{ Path = "Modules/OrchestratorAzure"; Script = "test-module.ps1" },
    @{ Path = "Modules/OrchestratorAzure"; Script = "test-connect-12azure-with-certificate.ps1" },
    @{ Path = "Modules/OrchestratorCommon"; Script = "test-module.ps1" },
    @{ Path = "Modules/Packaging"; Script = "test-manual-packaging-functions.ps1" },
    @{ Path = "Modules/Worker"; Script = "test-module.ps1" },
    @{ Path = "Modules/OrchestratorRouting"; Script = "test-module.ps1" },
    @{ Path = "Modules/OrchestratorRouting"; Script = "test-module-comprehensive.ps1" }
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
