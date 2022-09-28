param sqlServerConnection string
param azureBlobConnection string
param expenseReportLogicApp string
param integrationAccount string
param location string = resourceGroup().location
param externalAttachmentStorageName string
param externalResourceGroupName string
param externalSqlServerAddress string
param externalSqlDatabaseName string
param externalExpenseReportsBaseURI string
@secure()
param sqlUser string
@secure()
param sqlPass string

resource integrationAccount_resource 'Microsoft.Logic/integrationAccounts@2019-05-01' = {
  name: integrationAccount
  location: location
  sku: {
    name: 'Basic'
  }
  properties: {
    state: 'Enabled'
  }
}

resource ext_attachment_storage 'Microsoft.Storage/storageAccounts@2019-06-01' existing = {
  name: externalAttachmentStorageName
  scope: resourceGroup(externalResourceGroupName)
}

resource azureBlobConnection_resource 'Microsoft.Web/connections@2016-06-01' = {
  name: azureBlobConnection
  location: location
  properties: {
    displayName: 'storage-connection'
    parameterValues: {
      accountName: externalAttachmentStorageName
      accessKey: ext_attachment_storage.listKeys().keys[0].value
    }
    api: {
      id: subscriptionResourceId('Microsoft.Web/locations/managedApis', location, 'azureblob')
    }
  }
}

resource sqlServerConnection_resource 'Microsoft.Web/connections@2016-06-01' = {
  name: sqlServerConnection
  location: location
  properties: {
    displayName: 'sqldb-sqlserverauth-connection'
    parameterValues: {
      server: externalSqlServerAddress
      database: externalSqlDatabaseName
      username: sqlUser
      password: sqlPass
    }
    api: {
      id: subscriptionResourceId('Microsoft.Web/locations/managedApis', location, 'sql')
    }
  }
}

resource expenseReportLogicApp_resource 'Microsoft.Logic/workflows@2019-05-01' = {
  name: expenseReportLogicApp
  location: location
  properties: {
    state: 'Enabled'
    integrationAccount: {
      id: integrationAccount_resource.id
    }
    definition: {
      '$schema': 'https://schema.management.azure.com/providers/Microsoft.Logic/schemas/2016-06-01/workflowdefinition.json#'
      contentVersion: '1.0.0.0'
      parameters: {
        '$connections': {
          defaultValue: {
          }
          type: 'Object'
        }
      }
      triggers: {
        manual: {
          type: 'Request'
          kind: 'Http'
          inputs: {
            schema: {
              properties: {
                id: {
                  type: 'string'
                }
              }
              type: 'object'
            }
          }
        }
      }
      actions: {
        Compose_3: {
          runAfter: {
            Get_user_name: [
              'Succeeded'
            ]
          }
          type: 'Compose'
          inputs: '@variables(\'lineArray\')'
        }
        Execute_JavaScript_Code: {
          runAfter: {
            Compose_3: [
              'Succeeded'
            ]
          }
          type: 'JavaScriptCode'
          inputs: {
            code: 'var responseObj = {}\r\nresponseObj.header = workflowContext.actions.Parse_JSON.outputs.body.header\r\nresponseObj.header.firstName = workflowContext.actions.Get_user_name.outputs.body.FirstName\r\nresponseObj.header.surname = workflowContext.actions.Get_user_name.outputs.body.Surname\r\nresponseObj.lines = workflowContext.actions.Compose_3.outputs\r\n\r\nreturn responseObj'
          }
        }
        For_each_line: {
          foreach: '@body(\'Parse_JSON\')?[\'lines\']'
          actions: {
            Append_to_array_variable_2: {
              runAfter: {
                Replace_attachment_data: [
                  'Succeeded'
                ]
              }
              type: 'AppendToArrayVariable'
              inputs: {
                name: 'lineArray'
                value: '@body(\'Replace_attachment_data\')'
              }
            }
            Compose_2: {
              runAfter: {
                For_each_attachment: [
                  'Succeeded'
                ]
              }
              type: 'Compose'
              inputs: [
                '@items(\'For_each_line\')'
                '@variables(\'attachmentArray\')'
              ]
            }
            For_each_attachment: {
              foreach: '@items(\'For_each_line\')?[\'attachments\']'
              actions: {
                Append_to_array_variable: {
                  runAfter: {
                    Enrich_attachment_element: [
                      'Succeeded'
                    ]
                  }
                  type: 'AppendToArrayVariable'
                  inputs: {
                    name: 'attachmentArray'
                    value: '@body(\'Enrich_attachment_element\')'
                  }
                }
                Compose: {
                  runAfter: {
                    Create_SAS_URI_by_path: [
                      'Succeeded'
                    ]
                  }
                  type: 'Compose'
                  inputs: [
                    '@items(\'For_each_attachment\')'
                    '@body(\'Create_SAS_URI_by_path\')?[\'WebUrl\']'
                  ]
                }
                Create_SAS_URI_by_path: {
                  runAfter: {
                  }
                  type: 'ApiConnection'
                  inputs: {
                    body: {
                      Permissions: 'Read'
                    }
                    host: {
                      connection: {
                        name: '@parameters(\'$connections\')[\'azureblob\'][\'connectionId\']'
                      }
                    }
                    method: 'post'
                    path: '/v2/datasets/@{encodeURIComponent(\'AccountNameFromSettings\')}/CreateSharedLinkByPath'
                    queries: {
                      path: '/files/@{body(\'Parse_JSON\')?[\'header\']?[\'id\']}/@{items(\'For_each_line\')?[\'lineNumber\']}/@{items(\'For_each_attachment\')?[\'attachmentNumber\']}/@{items(\'For_each_attachment\')?[\'fileName\']}'
                    }
                  }
                }
                Enrich_attachment_element: {
                  runAfter: {
                    Compose: [
                      'Succeeded'
                    ]
                  }
                  type: 'JavaScriptCode'
                  inputs: {
                    code: 'var currentItem = workflowContext.actions.Compose.outputs[0]\r\ncurrentItem.uri = workflowContext.actions.Compose.outputs[1]\r\n\r\nreturn currentItem;'
                  }
                }
              }
              runAfter: {
                Set_variable: [
                  'Succeeded'
                ]
              }
              type: 'Foreach'
            }
            Replace_attachment_data: {
              runAfter: {
                Compose_2: [
                  'Succeeded'
                ]
              }
              type: 'JavaScriptCode'
              inputs: {
                code: 'var currentItem = workflowContext.actions.Compose_2.outputs[0]\r\ncurrentItem.attachments = []\r\ncurrentItem.attachments.push(workflowContext.actions.Compose_2.outputs[1])\r\n\r\nreturn currentItem;'
              }
            }
            Set_variable: {
              runAfter: {
              }
              type: 'SetVariable'
              inputs: {
                name: 'attachmentArray'
                value: []
              }
            }
          }
          runAfter: {
            Initialize_attachment_array: [
              'Succeeded'
            ]
          }
          type: 'Foreach'
          runtimeConfiguration: {
            concurrency: {
              repetitions: 1
            }
          }
        }
        Get_user_name: {
          runAfter: {
            For_each_line: [
              'Succeeded'
            ]
          }
          type: 'ApiConnection'
          inputs: {
            host: {
              connection: {
                name: '@parameters(\'$connections\')[\'sql\'][\'connectionId\']'
              }
            }
            method: 'get'
            path: '/v2/datasets/@{encodeURIComponent(encodeURIComponent(\'default\'))},@{encodeURIComponent(encodeURIComponent(\'default\'))}/tables/@{encodeURIComponent(encodeURIComponent(\'[dbo].[Users]\'))}/items/@{encodeURIComponent(encodeURIComponent(body(\'Parse_JSON\')?[\'header\']?[\'userId\']))}'
          }
        }
        HTTP: {
          runAfter: {
          }
          type: 'Http'
          inputs: {
            method: 'GET'
            uri: '${externalExpenseReportsBaseURI}/api/@{triggerBody()?[\'id\']}'
          }
        }
        Initialize_attachment_array: {
          runAfter: {
            Initialize_line_array: [
              'Succeeded'
            ]
          }
          type: 'InitializeVariable'
          inputs: {
            variables: [
              {
                name: 'attachmentArray'
                type: 'array'
                value: []
              }
            ]
          }
        }
        Initialize_line_array: {
          runAfter: {
            Parse_JSON: [
              'Succeeded'
            ]
          }
          type: 'InitializeVariable'
          inputs: {
            variables: [
              {
                name: 'lineArray'
                type: 'array'
                value: []
              }
            ]
          }
        }
        Parse_JSON: {
          runAfter: {
            HTTP: [
              'Succeeded'
            ]
          }
          type: 'ParseJson'
          inputs: {
            content: '@body(\'HTTP\')'
            schema: {
              properties: {
                header: {
                  properties: {
                    description: {
                      type: 'string'
                    }
                    endDate: {
                      type: 'string'
                    }
                    id: {
                      type: 'string'
                    }
                    startDate: {
                      type: 'string'
                    }
                    userId: {
                      type: 'string'
                    }
                  }
                  type: 'object'
                }
                lines: {
                  items: {
                    properties: {
                      amount: {
                        type: 'string'
                      }
                      attachments: {
                        items: {
                          properties: {
                            attachmentNumber: {
                              type: 'string'
                            }
                            description: {
                              type: 'string'
                            }
                            fileName: {
                              type: 'string'
                            }
                            fileType: {
                              type: 'string'
                            }
                          }
                          required: [
                            'attachmentNumber'
                            'description'
                            'fileName'
                            'fileType'
                          ]
                          type: 'object'
                        }
                        type: 'array'
                      }
                      currency: {
                        type: 'string'
                      }
                      description: {
                        type: 'string'
                      }
                      endDate: {
                        type: 'string'
                      }
                      endTime: {
                        type: 'string'
                      }
                      expenseType: {
                        type: 'string'
                      }
                      lineNumber: {
                        type: 'string'
                      }
                      startDate: {
                        type: 'string'
                      }
                      startTime: {
                        type: 'string'
                      }
                    }
                    required: [
                      'lineNumber'
                      'description'
                      'expenseType'
                      'startDate'
                      'endDate'
                      'amount'
                      'currency'
                      'attachments'
                    ]
                    type: 'object'
                  }
                  type: 'array'
                }
              }
              type: 'object'
            }
          }
        }
        Response: {
          runAfter: {
            Execute_JavaScript_Code: [
              'Succeeded'
            ]
          }
          type: 'Response'
          kind: 'Http'
          inputs: {
            body: '@body(\'Execute_JavaScript_Code\')'
            statusCode: 200
          }
        }
      }
      outputs: {
      }
    }
    parameters: {
      '$connections': {
        value: {
          azureblob: {
            connectionId: azureBlobConnection_resource.id
            connectionName: 'azureblob-conn'
            id: subscriptionResourceId('Microsoft.Web/locations/managedApis', location, 'azureblob')
          }
          sql: {
            connectionId: sqlServerConnection_resource.id
            connectionName: 'sql-conn'
            id: subscriptionResourceId('Microsoft.Web/locations/managedApis', location, 'sql')
          }
        }
      }
    }
  }
}

output logicAppGetUrl string = listCallbackURL('${expenseReportLogicApp_resource.id}/triggers/manual', '2019-05-01').value
