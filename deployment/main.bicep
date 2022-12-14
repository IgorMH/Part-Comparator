// Copyright (c) Microsoft Corporation.
// Licensed under the MIT license.

targetScope = 'subscription'

param userObjectID string

@secure()
param sqlPassword string

@maxLength(10)
@minLength(3)
@description('adding prefix to every resource names')
param resourceprefix string = take(guid(utcNow('u')),5)

resource rgPartComprator 'Microsoft.Resources/resourceGroups@2020-10-01' = {
  name: 'partcomparator-${resourceprefix}'
  location: deployment().location
}

module adlPartComparator 'deployDataLakeStorage.bicep' = {
  name : '${resourceprefix}adls'
  scope : rgPartComprator
  params : {
    storageAccountName: replace(replace(toLower('${resourceprefix}adls'),'-',''),'_','')
    containerName: 'sources'
  }
}

module synapseDeploy 'deploySynapse.bicep' = {
  name : '${resourceprefix}partcomparatorsynapse'
  scope: rgPartComprator
  params:{
    adlsStorageAccountURL: adlPartComparator.outputs.accountURL
    adlsFileSystem: adlPartComparator.outputs.filesystem
    sqlAdminLoginPassword: sqlPassword
    sqlAdminLoginId: 'sqladmin'
  }
}

module storageRoleDeployment 'deployStorageRoleAssignment.bicep' = {
  name: 'StorageRoleDeploymentResource'
  scope: rgPartComprator
  params:{
    synapseIdentity: synapseDeploy.outputs.identity
    synapseName: synapseDeploy.outputs.synapseWorkspaceName
    userObjectID: userObjectID
  }
}

output resourcegroupName string = 'partcomparator-${resourceprefix}'
output storageAccountName string = '${resourceprefix}adls'
output synapseworkspaceName string = synapseDeploy.outputs.synapseWorkspaceName