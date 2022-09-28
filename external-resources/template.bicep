param sqlserver_name string
param sqlserver_database_name string
param attachment_storage_name string
param expensereports_storage_name string
param location string = resourceGroup().location
@secure()
param sqlUser string
@secure()
param sqlPass string

resource sqlserver 'Microsoft.Sql/servers@2021-11-01-preview' = {
  name: '${sqlserver_name}-${uniqueString(resourceGroup().id)}'
  location: location
  properties: {
    administratorLogin: sqlUser
    administratorLoginPassword: sqlPass
    publicNetworkAccess: 'Enabled'
  }
}

resource sqlserver_database 'Microsoft.Sql/servers/databases@2021-11-01-preview' = {
  parent: sqlserver
  name: sqlserver_database_name
  location: location
  sku: {
    name: 'Basic'
    tier: 'Basic'
    capacity: 5
  }
}

resource sqlserver_firewall_rules 'Microsoft.Sql/servers/firewallRules@2021-11-01-preview' = {
  parent: sqlserver
  name: 'AllowAllWindowsAzureIps'
  properties: {
    endIpAddress: '0.0.0.0'
    startIpAddress: '0.0.0.0'
  }
}

var random_attachment_storage_name = substring('${attachment_storage_name}${uniqueString(resourceGroup().id)}', 0, 24)

resource attachment_storage 'Microsoft.Storage/storageAccounts@2021-09-01' = {
  name: random_attachment_storage_name
  location: location
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    allowBlobPublicAccess: false
    isHnsEnabled: true
    accessTier: 'Hot'
  }
}

resource attachment_storage_blob 'Microsoft.Storage/storageAccounts/blobServices@2021-09-01' = {
  parent: attachment_storage
  name: 'default'
}

resource attachment_storage_blob_container 'Microsoft.Storage/storageAccounts/blobServices/containers@2021-09-01' = {
  parent: attachment_storage_blob
  name: 'files'
}

var random_expensereports_storage_name = substring('${expensereports_storage_name}${uniqueString(resourceGroup().id)}', 0, 24)

resource expensereports_storage 'Microsoft.Storage/storageAccounts@2021-09-01' = {
  name: random_expensereports_storage_name
  location: location
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    allowBlobPublicAccess: true
    accessTier: 'Hot'
  }
}

resource expensereports_storage_blob 'Microsoft.Storage/storageAccounts/blobServices@2021-09-01' = {
  parent: expensereports_storage
  name: 'default'
}

resource expensereports_storage_blob_container 'Microsoft.Storage/storageAccounts/blobServices/containers@2021-09-01' = {
  parent: expensereports_storage_blob
  name: 'api'
  properties: {
    publicAccess: 'Blob'
  }
}
