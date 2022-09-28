# Creating a Bicep template from your Logic App and writing a GitHub Actions workflow

Use these instructions to learn how to convert your Logic App (and related resources) into a [Bicep template](https://docs.microsoft.com/en-us/azure/azure-resource-manager/bicep). These instructions also contain a brief introduction to [GitHub Actions workflows](https://docs.github.com/en/actions).

## 1. Exporting your resources into an ARM template

The only difference between those two alternative methods is that exporting using Azure Portal creates a separate `parameters.json` file inside the zip archive, while Azure CLI export doesn't create it automatically. Otherwise, `template.json` files should be semantically equal, although order of resource properties may not be the same (because order of properties doesn't matter in JSON).

### A. Using Azure Portal

The easiest way to export your Logic App and related resources is to open Azure portal, navigate to the resource group where your Logic App etc. are located (in my case, `samikomulainen-azuredemo2`), and select _Automation_ -> _Export template_ (1). Make sure you have selected _Include parameters_ option (2). Then click _Download_ to download resources from your resource group as a zipped ARM template and parameter file (3).
![Export template](/docs/images/export.png)

### B. Using Azure CLI

Another way to export a resource group is by using Azure CLI.

This command exports your resource group into an ARM template called `template.json`:

`az group export -g <<YOUR RESOURCE GROUP NAME>> --include-parameter-default-value > template.json`

After that command, please create a parameter file `parameters.json` like this:

```
{
    "$schema": "https://schema.management.azure.com/schemas/2015-01-01/deploymentParameters.json#",
    "contentVersion": "1.0.0.0",
    "parameters": {
        "connections_sql_conn_name": {
            "value": null
        },
        "connections_azureblob_conn_name": {
            "value": null
        },
        "workflows_combined_expensereport_name": {
            "value": null
        },
        "integrationAccounts_combined_expensereport_ia_name": {
            "value": null
        }
    }
}
```

where names of parameters match parameter definitions in `template.json` (at the beginning of the file, `parameters` property):

```
{
  "$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#",
  "contentVersion": "1.0.0.0",
  "parameters": {
    "connections_azureblob_conn_name": {
      "defaultValue": "azureblob-conn",
      "type": "String"
    },
    "connections_sql_conn_name": {
      "defaultValue": "sql-conn",
      "type": "String"
    },
    "integrationAccounts_combined_expensereport_ia_name": {
      "defaultValue": "combined-expensereport-ia",
      "type": "String"
    },
    "workflows_combined_expensereport_name": {
      "defaultValue": "combined-expensereport",
      "type": "String"
    }
  },
	.
	.
	.
```

## 2. From ARM templates to Bicep templates

We prefer to use newer and easier Bicep language templates instead of JSON ARM templates, so we give this command to convert ARM templates to Bicep templates:

`az bicep decompile -f template.json`

Convert operation may give some warnings but we can skip those.

## 3. Rename, refactor, simplify, and parameterize

**N.B.** When editing Bicep files, I recommend [VS Code and Bicep extension](https://learn.microsoft.com/en-us/azure/azure-resource-manager/bicep/install#vs-code-and-bicep-extension), because it can highlight error and warnings, and give autocomplete suggestions.

### More meaningful names

Although the Bicep template is usable as such when it comes to names, we prefer to use more meaningful names instead of automatically generated ones. So we're going to rename resources and resource references by doing these replace operations:

| Old value                                          | New value             | Files                          |
| -------------------------------------------------- | --------------------- | ------------------------------ |
| connections_sql_conn_name                          | sqlServerConnection   | template.bicep parameters.json |
| connections_azureblob_conn_name                    | azureBlobConnection   | template.bicep parameters.json |
| workflows_combined_expensereport_name              | expenseReportLogicApp | template.bicep parameters.json |
| integrationAccounts_combined_expensereport_ia_name | integrationAccount    | template.bicep parameters.json |

### Move default values of parameters to parameters file

Then we move parameter default values from `template.bicep` to `parameters.json`. So if parameter definitions in `template.bicep` were:

```
param sqlServerConnection string = 'sql-conn'
param azureBlobConnection string = 'azureblob-conn'
param expenseReportLogicApp string = 'combined-expensereport'
param integrationAccount string = 'combined-expensereport-ia'
```

we move them to `parameters.json`, so the parameter file should look like this now:

```
{
  "$schema": "https://schema.management.azure.com/schemas/2015-01-01/deploymentParameters.json#",
  "contentVersion": "1.0.0.0",
  "parameters": {
    "sqlServerConnectionName": {
      "value": "sql-conn"
    },
    "azureBlobConnectionName": {
      "value": "azureblob-conn"
    },
    "expenseReportLogicAppName": {
      "value": "combined-expensereport"
    },
    "integrationAccountName": {
      "value": "combined-expensereport-ia"
    }
}
```

and remove those from the Bicep template, so parameter definitions in `template.bicep` should look like this now:

```
param sqlServerConnection string
param azureBlobConnection string
param expenseReportLogicApp string
param integrationAccount string
```

### Replace hardcoded values

We don't like that _location_ property if explicitly defined for each resource, but instead prefer using the location of the resource group for that purpose. So we create a new parameter called _location_ and place it after existing parameters. It gets its value from the location of the resource group, like this:

```
param location string = resourceGroup().location
```

And then replace all _location_ properties with parameter _location_:

| Old value              | New value          | Files          |
| ---------------------- | ------------------ | -------------- |
| location: 'westeurope' | location: location | template.bicep |

After this replace e.g. Integration Account resource definition looks like this:

```
resource integrationAccount_resource 'Microsoft.Logic/integrationAccounts@2016-06-01' = {
  name: integrationAccount
  location: location
  sku: {
    name: 'Basic'
  }
  properties: {
    state: 'Enabled'
  }
}
```

This was only one example of course, but all resources should look the same when it comes to their _location_ property.

Next we're gonna replace hardcoded values in id references like this:

`id: '/subscriptions/<<YOUR SUBSCRIPTION ID>>/providers/Microsoft.Web/locations/<<YOUR RESOURCE GROUP LOCATION>>/managedApis/sql'`.

We'll utilize Bicep's [subscriptionResourceId](https://learn.microsoft.com/en-us/azure/azure-resource-manager/bicep/bicep-functions-resource#subscriptionresourceid) function that reads automatically the id of the default subscription - and which takes location and managed api name as parameters.

**Remember to replace `<<YOUR SUBSCRIPTION ID>>` and `<<YOUR RESOURCE GROUP LOCATION>>` with actual values from your environment before doing replace operations.**

| Old value                                                                                                                                | New value                                                                                | Files          |
| ---------------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------- | -------------- |
| `id: '/subscriptions/<<YOUR SUBSCRIPTION ID>>/providers/Microsoft.Web/locations/<<YOUR RESOURCE GROUP LOCATION>>/managedApis/sql'`       | id: subscriptionResourceId('Microsoft.Web/locations/managedApis', location, 'sql')       | template.bicep |
| `id: '/subscriptions/<<YOUR SUBSCRIPTION ID>>/providers/Microsoft.Web/locations/<<YOUR RESOURCE GROUP LOCATION>>/managedApis/azureblob'` | id: subscriptionResourceId('Microsoft.Web/locations/managedApis', location, 'azureblob') | template.bicep |

After that is done we take a look of our resource definitions one by one

### Integration Account (Microsoft.Logic/integrationAccounts)

If you're using VS Code and Bicep extension, you can see that it doesn't recognize _sku_ name 'Basic'. So we decide to use a newer API version (_2016-06-01_ => _2019-05-01_) like this:

```
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
```

### Storage Account Connection (Microsoft.Web/connections)

For a storage account connection, there's plenty of properties that are not mandatory, but which were read from an existing connection object. When creating this connection for the first time, those properties are not needed and we can remove those from the Bicep template. That way we can keep our template simple (to understand and to use).

We remove every property from resource `azureBlobConnection_resource` except these:

- name
- location
- properties/displayName
- properties/api/id

**N.B.** Beware, here it gets a bit tricky :)

As you can see from _properties/nonSecretParameterValues/accountName_ value (before removing those from the resource), this connection object is for the attachment storage from another resource group, and here we want to reference it (to get its correct name), not create it.

For that reason we must create a resource definition for this attachment storage, but we can specify it's an existing resource using `existing` keyword. But before doing that we must add two new template parameters: `externalAttachmentStorageName` and `externalAttachmentStorageName`. So, add these to `template.bicep` file after existing parameters:

```
param externalAttachmentStorageName string
param externalResourceGroupName string
```

and add those to `parameters.json` file after existing parameters (make sure their default values match your environment; what is shown here may not be correct):

```
"externalAttachmentStorageName": {
  "value": "myattachmentsigxpc2tf6zb"
},
"externalResourceGroupName": {
  "value": "samikomulainen-azuredemo1"
}
```

After those have been added, we can create a resource as a reference to an existing resource. Here we must give the name of the storage account and [scope](https://learn.microsoft.com/en-us/azure/azure-resource-manager/bicep/deploy-to-resource-group?tabs=azure-cli). In this case, scope must be defined because we're referencing a different resource group.

So, add this resource definition before resource called `azureBlobConnection_resource`:

```
resource ext_attachment_storage 'Microsoft.Storage/storageAccounts@2019-06-01' existing = {
  name: externalAttachmentStorageName
  scope: resourceGroup(externalResourceGroupName)
}
```

Now that this (external resource reference) is defined, we can use it in our template, because for fully initializing a storage account connection object we must read an access key of the attachment storage and use it as an initialization parameter. And we can do it using Bicep's [listKeys](https://learn.microsoft.com/en-us/azure/azure-resource-manager/templates/template-functions-resource#list) function like this:

```
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
```

<a name="MS_ManagedAPI"></a>
Now it gets really tricky. As far as I know, Microsoft documentation doesn't exactly say which parameters you must provide for a certain type of connection object, but I stumbled on [this blog post](https://isay.monogra.fi/2018/10/16/find-api-connection-parameters.html) that showed how use Microsoft's Manage API to find out suitable parameters. So, do `az login` and then `az account get-access-token --output json` to retrieve your access token that you're going to need next. Output from the previous command should look like this:

```
{
  "accessToken": "eyJ0eXAiOi...",
  "expiresOn": "2018-10-16 16:57:22.131352",
  "subscription": "<<YOUR SUBSCRIPTION ID>>",
  "tenant": "<<YOUR TENANT ID>>",
  "tokenType": "Bearer"
}
```

Then depending on a connection object type (_azureblob_ in our case), use curl or Postman to make a HTTP request to Microsoft's Manage API like this:

`curl -H "Authorization: Bearer <<YOUR ACCESS TOKEN>>" https://management.azure.com/subscriptions/<<YOUR SUBSCRIPTION ID>>/providers/Microsoft.Web/locations/<<YOUR RESOURCE GROUP LOCATION>>/managedApis/<<CONNECTION OBJECT TYPE>>?api-version=2016-06-01`

To give a more concrete example (**remember to replace sample access token `eyJ0eXAiOi...` with your own access token**):

`curl -H "Authorization: Bearer eyJ0eXAiOi..." https://management.azure.com/subscriptions/ae6cbacb-2eac-42cc-978e-516b8ef7628d/providers/Microsoft.Web/locations/westeurope/managedApis/azureblob?api-version=2016-06-01`

Output from that command was [this](/docs/files/manageapi_output.json). Even after getting that output, it may take a while to test which parameters are actually required in this scenario (access key based authentication) and you may need to google for similar samples.

In our case, _accountName_ and _accessKey_ are required, even though Manage API output doesn't say it so.

### SQL Server Connection (Microsoft.Web/connections)

Now that we have managed to find out how to initialize storage connection resource, let's use those learnings to SQL Server connection resource.

Here we do similar clean up and remove every property from resource `sqlServerConnection_resource` except these:

- name
- location
- properties/displayName
- properties/api/id

Using similar method [described earlier](/docs/from-logicapp-to-bicep.md#MS_ManagedAPI), we find out that for a _SQL Server Authentication_ method, these parameters are required:

- server (SQL server name/address)
- database (SQL database name)
- username (SQL user name)
- password (SQL user password)

We could create a resource reference to an existing SQL Server resource, but here we decide to reference it explicitly and use Bicep parameters for those above mentioned SQL Server Connection parameters. So, add these to `template.bicep` file after existing parameters:

```
param externalSqlServerAddress string
param externalSqlDatabaseName string
@secure()
param sqlUser string
@secure()
param sqlPass string
```

Notice that SQL Server username and password are defined as [secure parameters](https://learn.microsoft.com/en-us/azure/azure-resource-manager/bicep/parameters#secure-parameters), meaning that these parameter aren't saved to the deployment history and aren't logged during deployment. We also don't want to initialize those with any default values, and thus omit them from `parameters.json`. Those parameters will be initialized separately.

Then add not secure parameters to `parameters.json` file after existing parameters (make sure their default values match your environment; what is shown here may not be correct):

```
"externalSqlServerAddress": {
  "value": "myuserdbserver-igxpc2tf6zb7w.database.windows.net"
},
"externalSqlDatabaseName": {
  "value": "myuserdb"
}
```

After these parameters have been defined and initialized, we can use them to fully initialize our SQL Server connection object like this:

```
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
```

### Logic App (Microsoft.Logic/workflows)

If you're using VS Code and Bicep extension, you can see that it gives a warning `Resource type "Microsoft.Logic/workflows@2017-07-01" does not have types available`. So we decide to use a newer API version (_2017-07-01_ => _2019-05-01_) like this:

```
resource expenseReportLogicApp_resource 'Microsoft.Logic/workflows@2019-05-01' = {
```

Otherwise, Logic App resource looks pretty good already. Only thing we change here is the base URI of the external REST API, since it can vary from user to user. We give this base URI as a Bicep parameter called `externalExpenseReportsStorageName`. So, add this parameter to `template.bicep` file before secure parameters:

```
param externalExpenseReportsBaseURI string
```

and add a default value for it to `parameters.json` (make sure your default value match your environment; what is shown here may not be correct):

```
"externalExpenseReportsBaseURI": {
  "value": "https://myexpensereportsigxpc2tf.blob.core.windows.net"
}
```

So, this part of the Logic App:

```
HTTP: {
	inputs: {
		method: 'GET'
		uri: 'https://myexpensereportsigxpc2tf.blob.core.windows.net/api/@{triggerBody()?[\'id\']}'
	}
	runAfter: {
	}
	type: 'Http'
}
```

we replace with this one (where the base URI is given as a parameter):

```
HTTP: {
	runAfter: {
	}
	type: 'Http'
	inputs: {
		method: 'GET'
		uri: '${externalExpenseReportsBaseURI}/api/@{triggerBody()?[\'id\']}'
	}
}
```

Although it must be mentioned that tweaking Logic App code at this phase is ugly and it should be avoided if possible. And if we had been more thoughtful in the past, we should have used [Logic App parameters](https://learn.microsoft.com/en-us/azure/logic-apps/create-parameters-workflows?tabs=consumption) while we were creating our Logic App workflow in the Azure portal.

### Defining Bicep output parameter

Our Bicep template is almost finished, but there's one thing we like to do. By defining [output values](https://learn.microsoft.com/en-us/azure/azure-resource-manager/bicep/outputs?tabs=azure-cli), which are returned together with the results of the deployment, we can query those values later using Azure CLI.

Here we read the HTTP trigger URL of our Logic App and define it as an output value called `logicAppGetUrl`, which we'll use later when we test that our Logic App run has been successful. So add this to the bottom of your Bicep template:

```
output logicAppGetUrl string = listCallbackURL('${expenseReportLogicApp_resource.id}/triggers/manual', '2019-05-01').value
```

### Add files to Git repository

Now that our Bicep template and parameters file are ready, we can add those files to our Git repository. Folder `logic-app-resources` contains ready-made sample files, but our can replace those with our own.

If you'd like to keep both versions instead, create a new folder `my-logic-app-resources`, and add your Bicep template and parameters file under that folder.

## 4. Writing GitHub Actions workflow

Next we can start writing a GitHub Actions workflow that'll deploy our resources to Azure.

GitHub Actions workflows must be placed in `.github/workflows` folder, so we create this folder and create a new `logic-app-resources.yml` file under that folder.

Before you start writing GitHub Actions workflow files, take a look at your Bicep template and parameters file: which parameters are defined, which are given a default value, and which are defined as secure parameters. You must decide which parameters can be harcoded or defined as internal environment variables in you GitHub Actions workflow, and which you provide outside of your workflow file. Unless you're using a paid GitHub account, there's no way to define environment variables in your GitHub repository other than using [GitHub repository secrets](https://docs.github.com/en/actions/security-guides/encrypted-secrets) - which you can reference in you workflow file.

N.B. Please see this document if you like to know more about workflow file syntax: https://docs.github.com/en/actions/using-workflows/workflow-syntax-for-github-actions

We'll start our `logic-app-resources.yml` file by giving it a meaningful name (`name` property) that is shown to you when you trigger GitHub Actions workflows:

```
name: Deploy Logic App and related resources
```

Next we must decide which actions trigger our workflow (`on` property). We define that git push actions to main branch will trigger our workflow. Besides git push action, this workflow can be triggered also manually (`workflow_dispatch` property).

Usually it's enough to leave it like that but here we have defined a parameter for a manual trigger (`inputs` property) called `deployment_mode`. It's type is string and you can give additional information about this parameter to user using `description` property. A default value (`default` property) can be defined as well.

```
# Controls when the workflow will run
on:
  # Triggers the workflow on push or pull request events but only for the main branch
  push:
    branches: [ main ]
  # Allows you to run this workflow manually from the Actions tab
  workflow_dispatch:
    # This part (i.e. inputs) could be easily removed. It's here to easily allow deployment mode switching between *Complete* and *Incremental*.
    inputs:
      deployment_mode:
        description: 'Bicep template deployment mode (Complete/Incremental)'
        required: true
        default: 'Complete' # 'Complete' or 'Incremental'
        type: string
```

Sometimes triggering based on every git push to main is not required or wanted, so we can further restrict our trigger action [based on file path, tag or branch](https://docs.github.com/en/actions/using-workflows/workflow-syntax-for-github-actions#on).

Next we're going to define global environment variables (but internal to this workflow file) like this:

```
# Define environment variables
env:
  RESOURCE_GROUP_NAME: samikomulainen-azuredemo2
  TEMPLATE_PATH: logic-app-resources/template.bicep
  PARAMETERS_PATH: logic-app-resources/parameters.json
  DEPLOYMENT_MODE: ${{ github.event.inputs.deployment_mode }}
```

We've decided those values are not sensitive information, so we can use environment variables instead of repository secrets.

If you previously used a different folder (`my-logic-app-resources`) to store your Bicep and parameter files, you should change the folder path here like this:

```
  TEMPLATE_PATH: my-logic-app-resources/template.bicep
  PARAMETERS_PATH: my-logic-app-resources/parameters.json
```

A single workflow run can contain one or many jobs that can run sequentially or in parallel, but here we are using only one job called `build`. Each job must define a runner it uses (`runs-on` property). Basically this runner is a container or a virtual machine prepared for running different tasks, and it comes with preinstalled tools. [Here](https://github.com/actions/runner-images) you can find info about GitHub provided runners.

```
# A workflow run is made up of one or more jobs that can run sequentially or in parallel
jobs:
  # This workflow contains a single job called "build"
  build:
    # The type of runner that the job will run on
    runs-on: ubuntu-latest
```

Then under a single job called `build` we define steps we want our job to do. For example:

- Checkout our code from the repository (`actions/checkout@v2` action)
- Do Azure login (`Azure/login@v1` action)

Here `uses` property defines an action for an individual step. You can find available actions from [GitHub Marketplace](https://github.com/marketplace?type=actions). I recommend using actions from trusted sources (for Azure, from Microsoft or GitHub), and use Azure CLI commands instead of actions whenever possible - because you certainly can trust Azure CLI. Property `name` is not required, but it's nice to name your steps. Propery `with` means you're going to provide parameters for the action.

Please notice a syntax for referencing repository secrets: `${{ secrets.AZURE_CREDENTIALS_LA }}`. Here we have stored our Azure service principal as a repository secret called `AZURE_CREDENTIALS_LA`. See [this](/docs/logic-app-resources-deploy.md/#3-clonefork-repository-and-configure-github-repository-secrets) for more info how to do it.

```
    # Steps represent a sequence of tasks that will be executed as part of the job
    steps:
      # Checks-out your repository under $GITHUB_WORKSPACE, so your job can access it
      - uses: actions/checkout@v2

      # Do Azure login using your service principals
      - name: Azure Login
        uses: Azure/login@v1
        with:
          # Paste output of `az ad sp create-for-rbac` as value of secret variable: AZURE_CREDENTIALS_LA
          creds: ${{ secrets.AZURE_CREDENTIALS_LA }}
```

Next step doesn't use any action, but `run` property instead. This means that it runs command-line programs or scripts using the operating system's shell. Here we use Azure CLI to run a syntax check for our Bicep template file.

Please notice a syntax for referencing an environment variable we defined earlier: `${{ env.TEMPLATE_PATH }}`

```
      - name: Run Bicep linter
        run: az bicep build -f ${{ env.TEMPLATE_PATH }}
```

Then the final step (which easily could be split into separate steps). Please notice a syntax for running several command-line programs or scripts: `run: |`

Again, using Azure CLI, we set a default subscription (in case your Azure account has more than one active subscriptions).

Bicep install may not be needed anymore, but Ubuntu runner had a bug earlier, which required this.

Then we validate our Bicep template file against specified resource group and provided parameters. Here we use two repository secrets to initialize parameters besides those given in parameters file.

Then finally, we run a deployment of our resources. Here we use an option to name our deployment (`-n logicappdeploy` commandline parameter), because later, when we run a GitHub Actions workflow to test our Logic App, we read an output value from that named deployment. And we use here a named deployment to separate it from other deployments (which are named after their template file if `-n` parameter is not provided).

```
      - name: Deploy resources
        run: |
          echo "*** Set correct subscription (in case your Azure account has more than one active subscriptions) ***"
          az account set -s ${{ secrets.SUBSCRIPTION_ID }}
          echo "*** Install Bicep ***"
          az bicep install
          echo "*** Validate Bicep file ***"
          az deployment group validate -f ${{ env.TEMPLATE_PATH }} -g ${{ env.RESOURCE_GROUP_NAME }} \
            --mode ${{ env.DEPLOYMENT_MODE }} -p ${{ env.PARAMETERS_PATH }} \
            -p sqlUser='${{ secrets.SQL_USER }}' sqlPass='${{ secrets.SQL_PASS }}'
          echo "*** Do deploy ***"
          az deployment group create -n logicappdeploy -f ${{ env.TEMPLATE_PATH }} -g ${{ env.RESOURCE_GROUP_NAME }} \
            --mode ${{ env.DEPLOYMENT_MODE }} -p ${{ env.PARAMETERS_PATH }} \
            -p sqlUser='${{ secrets.SQL_USER }}' sqlPass='${{ secrets.SQL_PASS }}'
```
