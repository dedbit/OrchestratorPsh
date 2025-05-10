$repoUrl = git config --get remote.origin.url
$env:GITHUB_REPO_URL = "$($repoUrl)"

# terraform apply -var "github_repo_url=$env:GITHUB_REPO_URL" -auto-approve

terraform apply -var="input_parameters={""github_repo_url"":""$env:GITHUB_REPO_URL"",""another_variable"":""value1.1"",""yet_another_variable"":""value2""}" -auto-approve

$outputs = terraform output -json | ConvertFrom-Json
write-host $outputs.function_app_name.value

Write-Host -ForegroundColor Magenta "Outputs: "
$outputs |Out-Host


# $functionAppName = $outputs.deployment_outputs.value.function_app_name
# $resourceGroup = $outputs.deployment_outputs.value.resource_group_name
# $subscriptionId = $outputs.deployment_outputs.value.subscription_id
# $keyVaultName = $outputs.deployment_outputs.value.key_vault_name
# $aaName = $outputs.deployment_outputs.value.automation_account_name

# $key = az rest `
#   --method post `
#   --uri "https://management.azure.com/subscriptions/$subscriptionId/resourceGroups/$resourceGroup/providers/Microsoft.Web/sites/$functionAppName/host/default/listkeys?api-version=2022-03-01" `
#   --query masterKey `
#   --output tsv

# az keyvault secret set --vault-name $keyVaultName --name "FunctionAppMasterKey" --value $key


# az extension add --name automation

# az automation module create `
#   --automation-account-name $aaName `
#   --resource-group $resourceGroup `
#   --name PnP.PowerShell `
#   --content-link-uri "https://www.powershellgallery.com/api/v2/package/PnP.PowerShell"



# az automation module create \
#   --automation-account-name <AutomationAccountName> \
#   --resource-group <ResourceGroupName> \
#   --name "PnP.PowerShell" \
#   --content-link "https://www.powershellgallery.com/api/v2/package/PnP.PowerShell/1.12.0"


# az rest --method PUT `
#   --uri "https://management.azure.com/subscriptions/$subscriptionId/resourceGroups/$resourceGroup/providers/Microsoft.Automation/automationAccounts/$aaName/modules/PnP.PowerShell?api-version=2023-11-01" `
#   --headers "Content-Type=application/json" `
#   --body '{
#     "properties": {
#       "contentLink": {
#         "uri": "https://www.powershellgallery.com/api/v2/package/PnP.PowerShell/1.12.0"
#       }
#     }
#   }'



# $body = @{
#     properties = @{
#       contentLink = @{
#         uri = "https://www.powershellgallery.com/api/v2/package/PnP.PowerShell/1.12.0"
#       }
#     }
#   } | ConvertTo-Json
  
# az rest --method PUT `
#   --uri "https://management.azure.com/subscriptions/$subscriptionId/resourceGroups/$resourceGroup/providers/Microsoft.Automation/automationAccounts/$aaName/modules/PnP.PowerShell?api-version=2019-06-01" `
#   --headers "Content-Type=application/json" `
#   --body "$body"