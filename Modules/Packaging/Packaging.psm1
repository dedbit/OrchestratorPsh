# Packaging.psm1
# PowerShell module for packaging and publishing tasks.

function Get-PackageVersionFromNuspec {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$NuspecPath
    )
    Write-Host "Reading package version from: $NuspecPath" -ForegroundColor Cyan
    if (-not (Test-Path $NuspecPath)) {
        Write-Error "Nuspec file not found at $NuspecPath. Please build the package first or check the path."
        throw "Nuspec file not found: $NuspecPath"
    }
    $nuspecContent = Get-Content $NuspecPath -Raw
    if ($nuspecContent -match '<version>([0-9]+)\.([0-9]+)\.([0-9]+)</version>') {
        $major = $matches[1]
        $minor = $matches[2]
        $patch = $matches[3]
        $versionValue = "$major.$minor.$patch"
        Write-Host "Package version from nuspec: $versionValue" -ForegroundColor Cyan
        return $versionValue
    } else {
        Write-Error "Failed to find version in nuspec file: $NuspecPath"
        throw "Failed to find version in nuspec file: $NuspecPath"
    }
}

function Get-NuGetPATFromKeyVault {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$SecretName
    )
    # Access configuration values from the globally initialized configuration
    # Initialize-12Configuration stores config in $Global:12cConfig
    $kvName = $Global:12cConfig.keyVaultName
    $tenId = $Global:12cConfig.tenantId
    $subId = $Global:12cConfig.subscriptionId

    # Check if essential config values were found
    if ([string]::IsNullOrEmpty($kvName) -or [string]::IsNullOrEmpty($tenId) -or [string]::IsNullOrEmpty($subId)) {
        Write-Error "One or more required configuration values (KeyVaultName, TenantId, SubscriptionId) could not be retrieved from the global configuration (expected in \$Global:12cConfig). Ensure Initialize-12Configuration has run successfully and set them."
        throw "Missing KeyVault configuration from global scope."
    }

    Write-Host "Retrieving PAT from Key Vault: $kvName (Secret: $SecretName)" -ForegroundColor Cyan
    # Get-PATFromKeyVault is assumed to be available from an imported module (e.g., OrchestratorAzure)
    $pat = Get-PATFromKeyVault -KeyVaultName $kvName -SecretName $SecretName -TenantId $tenId -SubscriptionId $subId

    if ([string]::IsNullOrEmpty($pat)) {
        Write-Error "Failed to retrieve Personal Access Token from Key Vault for secret '$SecretName'. Aborting."
        throw "Failed to retrieve PAT from Key Vault for secret '$SecretName'."
    }
    return $pat
}

function Publish-NuGetPackageAndCleanup {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$PackagePath,

        [Parameter(Mandatory=$true)]
        [string]$FeedName
    )
    Write-Host "Pushing package '$PackagePath' to feed '$FeedName'..." -ForegroundColor Cyan
    nuget push $PackagePath -Source $FeedName -ApiKey "AzureDevOps" # ApiKey is often a placeholder for Azure Artifacts

    if ($LASTEXITCODE -ne 0) {
        Write-Error "Failed to publish NuGet package. NuGet exited with code $LASTEXITCODE."
        # Attempt to clean up the NuGet source even if push failed, but don't let this mask the original error
        Write-Host "Attempting to clean up NuGet source '$FeedName' after failed push..." -ForegroundColor Yellow
        try {
            nuget sources remove -Name $FeedName
        } catch {
            Write-Warning "Failed to remove NuGet source '$FeedName' during cleanup after failed push: $($_.Exception.Message)"
        }
        throw "NuGet push failed with exit code $LASTEXITCODE."
    } else {
        Write-Host "Package published successfully to '$FeedName'!" -ForegroundColor Green
    }

    # Clean up the NuGet source to remove sensitive information
    Write-Host "Cleaning up NuGet source '$FeedName' after successful push..." -ForegroundColor Cyan
    try {
        nuget sources remove -Name $FeedName
        if ($LASTEXITCODE -ne 0) {
            Write-Warning "Could not remove NuGet source '$FeedName' after successful push. Exit code: $LASTEXITCODE"
        }
    } catch {
        Write-Warning "An error occurred while trying to remove NuGet source '$FeedName' after successful push: $($_.Exception.Message)"
    }
}

function Ensure-NuGetFeedConfigured {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$FeedName,

        [Parameter(Mandatory=$true)]
        [string]$FeedUrl,

        [Parameter(Mandatory=$true)]
        [string]$PAT
    )

    Write-Host "Ensuring NuGet source '$FeedName' is correctly configured..." -ForegroundColor Cyan

    # Check if the source already exists
    Write-Host "Checking if NuGet source '$FeedName' already exists..."
    $sourceExistsOutput = nuget sources list -Name $FeedName -Format Short
    $sourceFound = $false
    if ($LASTEXITCODE -eq 0 -and $sourceExistsOutput) {
        if ($sourceExistsOutput -is [array]) {
            if ($sourceExistsOutput -join "\`n" -match [regex]::Escape($FeedName)) {
                $sourceFound = $true
            }
        } elseif ($sourceExistsOutput -is [string] -and $sourceExistsOutput -match [regex]::Escape($FeedName)) {
            $sourceFound = $true
        }
    }

    if ($sourceFound) {
        Write-Host "NuGet source '$FeedName' found. Removing it before re-adding..." -ForegroundColor Yellow
        nuget sources remove -Name $FeedName
        if ($LASTEXITCODE -ne 0) {
            Write-Warning "Failed to remove existing NuGet source '$FeedName'. Attempting to add it anyway."
        }
    } else {
        Write-Host "NuGet source '$FeedName' not found. Proceeding to add."
    }

    # Add the source
    nuget sources add -Name $FeedName -Source $FeedUrl -Username "AzureDevOps" -Password $PAT -StorePasswordInClearText
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Failed to add NuGet source '$FeedName'. NuGet exited with code $LASTEXITCODE."
        throw "Failed to add NuGet source '$FeedName'."
    }
    Write-Host "NuGet source '$FeedName' configured." -ForegroundColor Green
}

function Confirm-DirectoryExists { # Renamed from Ensure-DirectoryExists
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Path
    )
    if (-not (Test-Path -Path $Path)) {
        try {
            New-Item -ItemType Directory -Path $Path -ErrorAction Stop | Out-Null
            Write-Host "Created directory: $Path" -ForegroundColor Green
        } catch {
            Write-Error "Failed to create directory: $Path. Error: $($_.Exception.Message)"
            throw
        }
    } else {
        Write-Host "Directory already exists: $Path" -ForegroundColor Cyan
    }
}

function Set-PackageVersionIncrement { # Renamed from Increment-PackageVersion
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$NuspecPath,

        [Parameter(Mandatory=$false)]
        [string]$ModuleManifestPath
    )

    Write-Host "Incrementing package version for: $NuspecPath" -ForegroundColor Cyan
    if (-not (Test-Path $NuspecPath)) {
        Write-Error "Nuspec file not found at $NuspecPath."
        throw "Nuspec file not found: $NuspecPath"
    }

    $nuspecContent = Get-Content $NuspecPath -Raw
    if ($nuspecContent -match '<version>([0-9]+)\.([0-9]+)\.([0-9]+)</version>') {
        $major = [int]$matches[1]
        $minor = [int]$matches[2]
        $patch = [int]$matches[3] + 1
        $newVersion = "$major.$minor.$patch"

        # Update nuspec file
        $nuspecContent = $nuspecContent -replace '<version>[0-9]+\.[0-9]+\.[0-9]+</version>', "<version>$newVersion</version>"
        Set-Content -Path $NuspecPath -Value $nuspecContent
        Write-Host "Nuspec version updated to $newVersion in $NuspecPath" -ForegroundColor Cyan

        # Update module manifest if path is provided
        if (-not [string]::IsNullOrEmpty($ModuleManifestPath)) {
            if (Test-Path $ModuleManifestPath) {
                $moduleContent = Get-Content $ModuleManifestPath -Raw
                # Regex pattern now uses a here-string for robustness and to correctly escape dots for the regex engine.
                $regexFindPattern = @'
ModuleVersion\\s*=\\s*['"]([0-9]+\\.[0-9]+\\.[0-9]+)['"]
'@
                $regexReplaceWith = "ModuleVersion = '$newVersion'"
                $moduleContent = $moduleContent -replace $regexFindPattern, $regexReplaceWith
                Set-Content -Path $ModuleManifestPath -Value $moduleContent
                Write-Host "Module manifest version updated to $newVersion in $ModuleManifestPath" -ForegroundColor Cyan
            } else {
                Write-Warning "Module manifest file not found at $ModuleManifestPath. Skipping update."
            }
        }
        return $newVersion
    } else {
        Write-Error "Failed to find version in nuspec file: $NuspecPath"
        throw "Failed to find version in nuspec file: $NuspecPath"
    }
}

function Invoke-NuGetPack {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$NuspecPath,

        [Parameter(Mandatory=$true)]
        [string]$OutputDirectory,

        [Parameter(Mandatory=$false)]
        [string]$NuGetExePath = "nuget.exe" # Default to nuget.exe in PATH
    )

    Write-Host "Building NuGet package from $NuspecPath to $OutputDirectory..." -ForegroundColor Cyan
    
    # Ensure NuGet executable exists or is in PATH
    if ($NuGetExePath -ne "nuget.exe" -and -not (Test-Path $NuGetExePath)) {
        Write-Error "NuGet executable not found at specified path: $NuGetExePath"
        throw "NuGet executable not found: $NuGetExePath"
    }
    
    try {
        & $NuGetExePath pack $NuspecPath -OutputDirectory $OutputDirectory
        if ($LASTEXITCODE -eq 0) {
            Write-Host "NuGet package built successfully." -ForegroundColor Green
        } else {
            Write-Error "Failed to build NuGet package. NuGet exited with code $LASTEXITCODE."
            throw "NuGet pack failed with exit code $LASTEXITCODE."
        }
    } catch {
        Write-Error "An error occurred during NuGet pack: $($_.Exception.Message)"
        throw
    }
}

function Remove-OldPackageVersions {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$OutputDirectory,

        [Parameter(Mandatory=$true)]
        [string]$PackageBaseName,

        [Parameter(Mandatory=$true)]
        [string]$VersionToKeep # Expected format X.Y.Z
    )

    Write-Host "Removing old package versions for '$PackageBaseName' in '$OutputDirectory', keeping version '$VersionToKeep'..." -ForegroundColor Cyan
    $packageFileToKeep = "$($PackageBaseName).$($VersionToKeep).nupkg"
    
    Get-ChildItem -Path $OutputDirectory -Filter "$($PackageBaseName).*.nupkg" | ForEach-Object {
        if ($_.Name -ne $packageFileToKeep) {
            Write-Host "Deleting old package: $($_.Name)" -ForegroundColor Yellow
            try {
                Remove-Item -Path $_.FullName -Force -ErrorAction Stop
            } catch {
                Write-Warning "Failed to delete old package: $($_.FullName). Error: $($_.Exception.Message)"
            }
        }
    }
}


# Export the functions to make them available when the module is imported
Export-ModuleMember -Function 'Get-PackageVersionFromNuspec', 'Get-NuGetPATFromKeyVault', 'Publish-NuGetPackageAndCleanup', 'Ensure-NuGetFeedConfigured', 'Confirm-DirectoryExists', 'Set-PackageVersionIncrement', 'Invoke-NuGetPack', 'Remove-OldPackageVersions'
