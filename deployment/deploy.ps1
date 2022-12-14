# Copyright (c) Microsoft Corporation.
# Licensed under the MIT license.

param(
    # [Parameter(Mandatory= $True,
    #              HelpMessage='Write your subscription ID to deploy your resources')]
    #  [string]
    #  $subscriptionID = '',
    # [Parameter(Mandatory= $True,
    #             HelpMessage='Digite o data center que deseja fazer o deploy:')]
    # [string]
    # $location = '',
    [Parameter(Mandatory= $True,
                HelpMessage='Digite uma senha para o Pool SQL:')]
    [securestring]
    $sqlpassword = ''
)

$location = 'westus3'

Write-Host "Login Azure.....`r`n"

az login -o none
$subscriptionID = az account show --query id -o tsv
Write-Host "Assinatura selecionada: '$subscriptionID'"
az account set --subscription $subscriptionID

$userObjectID = az ad signed-in-user show --query id -o tsv
Write-Host "Este é o Id de objeto do usuario: '$userObjectID'"

$deploymentResult = az deployment sub create --template-file .\azuredeploy.json -l $location -n 'partcomparatorsa' -p userObjectID=$userObjectID sqlPassword=$sqlpassword
$joinedString = $deploymentResult -join "" 
$jsonString = ConvertFrom-Json $joinedString

$resourceGroupName = $jsonString.properties.outputs.resourcegroupName.value
$storageAccountName = $jsonString.properties.outputs.storageAccountName.value
$synapseWorkspaceName = $jsonString.properties.outputs.synapseworkspaceName.value

Write-Host "O deploy dos recursos esta completo"
Write-Host "Fazendo upload dos dados no Azure Data Lake: $storageAccountName"
$storageAccountKey = az storage account keys list --resource-group $resourceGroupName --account-name $storageAccountName --query "[?keyName == 'key1'].value" -o tsv
az storage blob upload-batch -d sources --account-key $storageAccountKey --account-name $storageAccountName -s '..\data'

Write-Host "Fazendo upload dos notebooks na area de trabalho do Synapse:($synapseWorkspaceName)"

az synapse notebook import --workspace-name $synapseWorkspaceName --name DataPreparation --file "@..\src\notebooks\Data_Preparation.ipynb" -o none --spark-pool-name 'sparkpool1'
az synapse notebook import --workspace-name $synapseWorkspaceName --name DataModeling --file "@..\src\notebooks\Modeling.ipynb" -o none

Write-Host "Todo processo esta completo"