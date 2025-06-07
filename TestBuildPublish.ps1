# TestBuildPublish.ps1
# Runs build and publish scripts in directories that contain both, using pushd/popd for isolation

$ErrorActionPreference = 'Stop'

$buildPublishDirectories = @(
    "CoreUpdaterPackage",
    "Modules/CommonConnections",
    "Modules/Configuration",
    "Modules/MessagingModule", 
    "Modules/OrchestratorAzure",
    "Modules/OrchestratorCommon",
    "Modules/Packaging"

    
)

foreach ($directory in $buildPublishDirectories) {
    $buildScript = Join-Path $directory "build.ps1"
    $publishScript = Join-Path $directory "publish.ps1"
    
    # Check if both scripts exist before proceeding
    if ((Test-Path $buildScript) -and (Test-Path $publishScript)) {
        Write-Host "`n--- Processing $directory ---" -ForegroundColor Cyan
        pushd $directory
        try {
            # Run build script first
            Write-Host "Running build.ps1..." -ForegroundColor Yellow
            & ".\build.ps1"
            Write-Host "Build script completed successfully." -ForegroundColor Green
            
            # Run publish script second
            Write-Host "Running publish.ps1..." -ForegroundColor Yellow
            & ".\publish.ps1"
            Write-Host "Publish script completed successfully." -ForegroundColor Green
            
        } catch {
            Write-Host "Script failed in $directory`: $($_.Exception.Message)" -ForegroundColor Red
        } finally {
            popd
        }
    } else {
        Write-Host "Skipping $directory - missing build.ps1 or publish.ps1" -ForegroundColor Yellow
    }
}

Write-Host "`nAll build and publish scripts processed." -ForegroundColor Cyan