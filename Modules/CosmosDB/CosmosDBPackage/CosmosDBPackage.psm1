# CosmosDBPackage.psm1
# Module for CosmosDB operations used across OrchestratorPsh scripts

# Function to get CosmosDB connection details from Key Vault
function Get-12cCosmosConnection {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $false)]
        [string]$DatabaseName = "12cOrchestrator",
        [Parameter(Mandatory = $false)]
        [string]$ContainerName = "Items"
    )

    # Ensure global configuration is loaded
    if (-not $Global:12cConfig) {
        throw "Global configuration not found. Please run Initialize-12Configuration first."
    }

    $keyVaultName = $Global:12cConfig.keyVaultName
    $cosmosAccountName = $Global:12cConfig.cosmosDbAccountName

    try {
        # Check if Azure modules are available
        $azModuleAvailable = Get-Module -ListAvailable -Name "Az.KeyVault" -ErrorAction SilentlyContinue
        if (-not $azModuleAvailable) {
            throw "Az.KeyVault module is not available. Please install Azure PowerShell modules."
        }

        # Get connection string from Key Vault
        $connectionStringSecretName = "CosmosDbConnectionString"
        $connectionStringSecret = Get-AzKeyVaultSecret -VaultName $keyVaultName -Name $connectionStringSecretName -AsPlainText
        
        if (-not $connectionStringSecret) {
            throw "CosmosDB connection string not found in Key Vault secret '$connectionStringSecretName'"
        }

        return @{
            ConnectionString = $connectionStringSecret
            AccountName = $cosmosAccountName
            DatabaseName = $DatabaseName
            ContainerName = $ContainerName
        }
    }
    catch {
        Write-Error "Failed to get CosmosDB connection: $($_.Exception.Message)"
        throw
    }
}

# Function to get an item from CosmosDB
function Get-12cItem {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$Id,
        [Parameter(Mandatory = $false)]
        [string]$PartitionKey,
        [Parameter(Mandatory = $false)]
        [string]$DatabaseName = "12cOrchestrator",
        [Parameter(Mandatory = $false)]
        [string]$ContainerName = "Items"
    )

    try {
        # Get connection details
        $connection = Get-12cCosmosConnection -DatabaseName $DatabaseName -ContainerName $ContainerName

        # If no partition key provided, use the ID as partition key
        if ([string]::IsNullOrEmpty($PartitionKey)) {
            $PartitionKey = $Id
        }

        $accountEndpoint = ($connection.ConnectionString -split 'AccountEndpoint=')[1] -split ';' | Select-Object -First 1
        $accountKey = ($connection.ConnectionString -split 'AccountKey=')[1] -split ';' | Select-Object -First 1

        $resourcePath = "dbs/$DatabaseName/colls/$ContainerName/docs/$Id"
        $date = [DateTime]::UtcNow.ToString("r")
        $verb = "GET"
        $stringToSign = "$($verb.ToLower())`ndocs`n$resourcePath`n$($date.ToLower())`n`n"

        $hmacSha = New-Object System.Security.Cryptography.HMACSHA256
        $hmacSha.Key = [Convert]::FromBase64String($accountKey)
        $hash = $hmacSha.ComputeHash([Text.Encoding]::UTF8.GetBytes($stringToSign))
        $sig = [Convert]::ToBase64String($hash)
        $auth = "type=master&ver=1.0&sig=$sig"

        $headers = @{
            Authorization     = [System.Web.HttpUtility]::UrlEncode($auth)  # URL-encode for CosmosDB REST API
            "x-ms-date"       = $date
            "x-ms-version"    = "2018-12-31"
            "x-ms-documentdb-partitionkey" = '["' + $PartitionKey + '"]'
        }

        $uri = "$($accountEndpoint.TrimEnd('/'))/$resourcePath"
        $response = Invoke-RestMethod -Uri $uri -Headers $headers -Method GET
        return $response
    }
    catch {
        Write-Error "Failed to get item '$Id' from CosmosDB: $($_.Exception.Message)"
        throw
    }
}

# Function to set/upsert an item in CosmosDB
function Set-12cItem {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [object]$Item,
        [Parameter(Mandatory = $false)]
        [string]$DatabaseName = "12cOrchestrator",
        [Parameter(Mandatory = $false)]
        [string]$ContainerName = "Items"
    )

    try {
        # Get connection details
        $connection = Get-12cCosmosConnection -DatabaseName $DatabaseName -ContainerName $ContainerName

        # Ensure the item has an id property
        if (-not $Item.id) {
            throw "Item must have an 'id' property"
        }

        # Ensure the item has a partitionKey property, default to id if missing
        if (-not $Item.partitionKey) {
            $Item | Add-Member -MemberType NoteProperty -Name 'partitionKey' -Value $Item.id -Force
        }

        $accountEndpoint = ($connection.ConnectionString -split 'AccountEndpoint=')[1] -split ';' | Select-Object -First 1
        $accountKey = ($connection.ConnectionString -split 'AccountKey=')[1] -split ';' | Select-Object -First 1

        $resourcePath = "dbs/$DatabaseName/colls/$ContainerName"
        $uri = "$($accountEndpoint.TrimEnd('/'))/$resourcePath/docs"
        $date = [DateTime]::UtcNow.ToString("r")
        $verb = "POST"
        $stringToSign = "$($verb.ToLower())`ndocs`n$resourcePath`n$($date.ToLower())`n`n"

        $hmacSha = New-Object System.Security.Cryptography.HMACSHA256
        $hmacSha.Key = [Convert]::FromBase64String($accountKey)
        $hash = $hmacSha.ComputeHash([Text.Encoding]::UTF8.GetBytes($stringToSign))
        $sig = [Convert]::ToBase64String($hash)
        $auth = "type=master&ver=1.0&sig=$sig"

        $headers = @{
            Authorization     = [System.Web.HttpUtility]::UrlEncode($auth)
            "x-ms-date"       = $date
            "x-ms-version"    = "2018-12-31"
            "x-ms-documentdb-is-upsert" = "true"
            "x-ms-documentdb-partitionkey" = '["' + $Item.partitionKey + '"]'
            "Content-Type"    = "application/json"
        }

        $body = $Item | ConvertTo-Json -Depth 10
        $response = Invoke-RestMethod -Uri $uri -Headers $headers -Method POST -Body $body
        return $response
    }
    catch {
        Write-Error "Failed to set item in CosmosDB: $($_.Exception.Message)"
        throw
    }
}

# Function to delete an item from CosmosDB
function Remove-12cItem {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$Id,
        [Parameter(Mandatory = $false)]
        [string]$PartitionKey,
        [Parameter(Mandatory = $false)]
        [string]$DatabaseName = "12cOrchestrator",
        [Parameter(Mandatory = $false)]
        [string]$ContainerName = "Items"
    )

    try {
        # Get connection details
        $connection = Get-12cCosmosConnection -DatabaseName $DatabaseName -ContainerName $ContainerName

        # If no partition key provided, use the ID as partition key
        if ([string]::IsNullOrEmpty($PartitionKey)) {
            $PartitionKey = $Id
        }

        $accountEndpoint = ($connection.ConnectionString -split 'AccountEndpoint=')[1] -split ';' | Select-Object -First 1
        $accountKey = ($connection.ConnectionString -split 'AccountKey=')[1] -split ';' | Select-Object -First 1

        $resourcePath = "dbs/$DatabaseName/colls/$ContainerName/docs/$Id"
        $date = [DateTime]::UtcNow.ToString("r")
        $verb = "DELETE"
        $stringToSign = "$($verb.ToLower())`ndocs`n$resourcePath`n$($date.ToLower())`n`n"

        $hmacSha = New-Object System.Security.Cryptography.HMACSHA256
        $hmacSha.Key = [Convert]::FromBase64String($accountKey)
        $hash = $hmacSha.ComputeHash([Text.Encoding]::UTF8.GetBytes($stringToSign))
        $sig = [Convert]::ToBase64String($hash)
        $auth = "type=master&ver=1.0&sig=$sig"

        $headers = @{
            Authorization     = [System.Web.HttpUtility]::UrlEncode($auth)  # URL-encode for CosmosDB REST API
            "x-ms-date"       = $date
            "x-ms-version"    = "2018-12-31"
            "x-ms-documentdb-partitionkey" = '["' + $PartitionKey + '"]'
        }

        $uri = "$($accountEndpoint.TrimEnd('/'))/$resourcePath"
        $response = Invoke-RestMethod -Uri $uri -Headers $headers -Method DELETE
        return $response
    }
    catch {
        Write-Error "Failed to delete item '$Id' from CosmosDB: $($_.Exception.Message)"
        throw
    }
}

# Function to execute SQL queries against CosmosDB
function Invoke-12cCosmosDbSqlQuery {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$SqlQuery,
        [Parameter(Mandatory = $false)]
        [string]$DatabaseName = "12cOrchestrator",
        [Parameter(Mandatory = $false)]
        [string]$ContainerName = "Items",
        [Parameter(Mandatory = $false)]
        [hashtable]$Parameters = @{}
    )

    try {
        # Get connection details
        $connection = Get-12cCosmosConnection -DatabaseName $DatabaseName -ContainerName $ContainerName

        $accountEndpoint = ($connection.ConnectionString -split 'AccountEndpoint=')[1] -split ';' | Select-Object -First 1
        $accountKey = ($connection.ConnectionString -split 'AccountKey=')[1] -split ';' | Select-Object -First 1

        $resourcePath = "dbs/$DatabaseName/colls/$ContainerName"
        $date = [DateTime]::UtcNow.ToString("r")
        $verb = "POST"
        $stringToSign = "$($verb.ToLower())`ndocs`n$resourcePath`n$($date.ToLower())`n`n"

        $hmacSha = New-Object System.Security.Cryptography.HMACSHA256
        $hmacSha.Key = [Convert]::FromBase64String($accountKey)
        $hash = $hmacSha.ComputeHash([Text.Encoding]::UTF8.GetBytes($stringToSign))
        $sig = [Convert]::ToBase64String($hash)
        $auth = "type=master&ver=1.0&sig=$sig"

        $headers = @{
            Authorization     = [System.Web.HttpUtility]::UrlEncode($auth)
            "x-ms-date"       = $date
            "x-ms-version"    = "2018-12-31"
            "Content-Type"    = "application/query+json"
            "x-ms-documentdb-isquery" = "true"
            "x-ms-documentdb-query-enablecrosspartition" = "true"
        }

        # Build query body
        $queryBody = @{
            query = $SqlQuery
        }

        # Add parameters if provided
        if ($Parameters.Count -gt 0) {
            $queryParameters = @()
            foreach ($key in $Parameters.Keys) {
                $queryParameters += @{
                    name = "@$key"
                    value = $Parameters[$key]
                }
            }
            $queryBody.parameters = $queryParameters
        }

        $uri = "$($accountEndpoint.TrimEnd('/'))/$resourcePath/docs"
        $body = $queryBody | ConvertTo-Json -Depth 10
        
        $response = Invoke-RestMethod -Uri $uri -Headers $headers -Method POST -Body $body
        
        # Always return a collection, even if empty
        if ($response.Documents) {
            return $response.Documents
        } else {
            # Return an empty array as a single-item array to prevent unwrapping
            # This is a PowerShell-specific workaround for empty array unwrapping behavior
            return ,(New-Object 'object[]' 0)
        }
    }
    catch {
        Write-Error "Failed to execute SQL query against CosmosDB: $($_.Exception.Message)"
        throw
    }
}

# Export the functions
Export-ModuleMember -Function Get-12cItem, Set-12cItem, Remove-12cItem, Get-12cCosmosConnection, Invoke-12cCosmosDbSqlQuery