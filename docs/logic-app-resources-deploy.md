# Deploying and testing a ready-made Logic App and its required resources

These are instructions how to deploy a ready-made Logic App and its required resources to Azure.

If you're looking for a guide how to convert your own Logic App, you've developed on Azure portal, and its required resources into Bicep template, please see [this guide](/docs/from-logicapp-to-bicep.md).

I've included instructions how to do [deploy manually (using Azure CLI)](#manual-deploy-using-azure-cli) or [using GitHub Actions workflow](#deploy-using-github-actions-workflow).

## Manual deploy (using Azure CLI)

### 1. Azure CLI login

Type [`az login`](https://docs.microsoft.com/en-us/cli/azure/authenticate-azure-cli) and follow instructions. A browser window/tab is opened and you must fill your credentials (Azure portal username and password).

If you have more than one active Azure subscriptions, you must choose the correct one with [`az account set -s <<YOUR SUBSCRIPTION ID>>`](https://docs.microsoft.com/en-us/cli/azure/manage-azure-subscriptions-azure-cli#change-the-active-subscription)

### 2. Create a resource group using Azure CLI

[`az group create --name <<YOUR RESOURCE GROUP NAME>> --location <<YOUR RESOURCE GROUP LOCATION>>`](https://docs.microsoft.com/en-us/cli/azure/group?view=azure-cli-latest#az-group-create)

You must at least specify a resource group name. You must also specify a resource group location (e.g. `westeurope`) if you haven't set a default location.

### 3. Review and modify deploy parameters

File [`logic-app-resources/parameters.json`](/logic-app-resources/parameters.json) contains default values for:

- SQL Server connection object for Logic App (`sqlServerConnection`)
- Azure Storage Account connection object for Logic App (`azureBlobConnection`)
- Logic App name (`expenseReportLogicApp`)
- Integration Account name (`integrationAccount`)
- Azure Storage Container name for attachment files (`externalAttachmentStorageName`)
- Resource group name of the external resources (`externalResourceGroupName`)
- SQL Server address (`externalSqlServerAddress`)
- SQL Server database name (`externalSqlDatabaseName`)
- External REST API base URI (`externalExpenseReportsBaseURI`)

Review those parameter values and mofidy them if needed. Values for parameters

- `sqlServerConnection`,
- `azureBlobConnection`,
- `expenseReportLogicApp`, and
- `integrationAccount`

can be whatever, but all the rest (`externalXXXXXX` parameters) **must** be correct, otherwise deployment or the Logic App doesn't work correctly.

To find out how your resources are named in external resources resource group, run this command against resource group where they are deployed:

`az resource list -g <<EXTERNAL RESOURCES RESOURCE GROUP>> --query "[].{Name: name, Type: type}"`

Here you must replace `<<EXTERNAL RESOURCES RESOURCE GROUP>>` with the name of the actual resource group.

Then modify [`logic-app-resources/parameters.json`](/logic-app-resources/parameters.json) file, and replace sample values of `externalXXXX` in the file with actual values.

### 4. Validate Bicep file

Do syntax check for a Bicep file:

`az bicep build -f logic-app-resources/template.bicep`

If there are errors or warnings after running the previous command, you should check those issues before proceeding to the next step.

If you get these warnings, you can ignore them. I've written the Bicep template file so that certain things generate warnings.

```
Warning outputs-should-not-contain-secrets: Outputs should not contain secrets. Found possible secret: function 'listCallbackURL' [https://aka.ms/bicep/linter/outputs-should-not-contain-secrets]
```

Validate whether a template is valid at resource group:

`az deployment group validate -f logic-app-resources/template.bicep -g <<YOUR RESOURCE GROUP NAME>> --mode Complete -p logic-app-resources/parameters.json -p sqlUser=<<YOUR SQL SERVER USERNAME>> sqlPass=<<YOUR SQL SERVER PASSWORD>>`

N.B. Bicep file [`logic-app-resources/template.bicep`](/logic-app-resources/template.bicep) contains secret parameters for SQL Server user name and password. For security reasons those are not given in the parameter file, but you must give them yourself when running a deploy command.

If there are errors or warnings after running the previous command, you should check those issues before proceeding to the next step.

### 5. Deploy resources defined in Bicep file

Do deploy:

`az deployment group create -n logicappdeploy -f logic-app-resources/template.bicep -g <<YOUR RESOURCE GROUP NAME>> --mode Complete -p logic-app-resources/parameters.json -p sqlUser=<<YOUR SQL SERVER USERNAME>> sqlPass=<<YOUR SQL SERVER PASSWORD>>`

### 6. Test the deployed Logic App

For testing the Logic App, you must have curl (or compatible program) installed.

Retrieve the callback url the Logic App:
`az deployment group show -g <<YOUR RESOURCE GROUP NAME>> -n logicappdeploy --query "properties.outputs.logicAppGetUrl.value" --output tsv`

Store the returned value and use curl to call the Logic App:
`curl -k --header "Content-Type: application/json" -X POST -d @logic-app-testing/input/test_la.json "<<PREVIOUSLY STORED CALLBACK URL>>"`

If this returns some error, you can test the Logic App also using Azure Portal using _Run with payload_ option.

Please notice that sometimes integration account provisioning takes some time, and because of that Logic App execution fails. If that is the case, please try running the test again later.

Compare the output from curl with file _[output_sample2.json](/logic-app-testing/output/output_sample2.json)_. They should be similar in every way except the SAS URIs. Although even SAS URIs should be identical if we skip the name of the storage account and HTTP URL parameters.

If you are using a bash compatible shell, and have installed _curl_ and _jq_, you can run the test using this script (you just have to replace `<<YOUR RESOURCE GROUP NAME>>` with your actual resource group name):

```
export CALLBACK_URL=$(az deployment group show -g <<YOUR RESOURCE GROUP NAME>> -n logicappdeploy --query "properties.outputs.logicAppGetUrl.value" --output tsv)
curl -k --header "Content-Type: application/json" -X POST -d @logic-app-testing/input/test_la.json "$CALLBACK_URL" | jq . | tee response.json
jq --sort-keys . response.json > response.json.sorted
jq --sort-keys . logic-app-testing/output/output_sample2.json > output_sample2.json.sorted
diff -I ".blob.core.windows.net/files/0e442f4f-5b37-49a2-b677-c1013c13e32f/1/receipt.jpg" response.json.sorted output_sample2.json.sorted
```

## Deploy using GitHub Actions workflow

If you like to use CI/CD based approach to deploy a Logic App and its required resources using GitHub Actions workflow, here's what you need to do:

### 1. Create a resource group

Create a resource group for a Logic App and its required resources either using Azure Portal or Azure CLI (_see [instructions for creating a resource group using Azure CLI](#2-create-a-resource-group-using-azure-cli)_).

N.B. This resource group must be created within the same subscription as the resource group for the external resources.

### 2. Create (or ask someone to create them for you) service principals

In order to use GitHub Actions to deploy Azure resources, you have to have a [service principal](https://learn.microsoft.com/en-us/cli/azure/create-an-azure-service-principal-azure-cli), which allows you to authenticate against Azure and run deploy operations without having to manually provide your credentials.

When creating a service principal, make sure it has contributor rights to the resource group you created earlier in [step 1](#1-create-a-resource-group).

You can create a service principal using Azure CLI:

`az ad sp create-for-rbac --name <<YOUR SERVICE PRINCIPAL NAME>> --role contributor --scopes /subscriptions/<<YOUR SUBSCRIPTION ID>>/resourceGroups/<<YOUR RESOURCE GROUP NAME>> --sdk-auth`

You can query the id of your current Azure subscription like this: `az account show --query id`

Output of `az ad sp create-for-rbac` command is something like this:

```
{
  "clientId": "3e205e08-b990-4598-a8e3-9c0bf54c5f5e",
  "clientSecret": "<<SOME SECRET STRING>>",
  "subscriptionId": "<<YOUR SUBSCRIPTION ID>>",
  "tenantId": "<<YOUR TENANT ID>>",
  "activeDirectoryEndpointUrl": "https://login.microsoftonline.com",
  "resourceManagerEndpointUrl": "https://management.azure.com/",
  "activeDirectoryGraphResourceId": "https://graph.windows.net/",
  "sqlManagementEndpointUrl": "https://management.core.windows.net:8443/",
  "galleryEndpointUrl": "https://gallery.azure.com/",
  "managementEndpointUrl": "https://management.core.windows.net/"
}
```

Store this output because you'll need to later on.

### 3. Clone/fork repository and configure GitHub repository secrets

_If you have already created these when deploying external resources, there's no need to recreate/update these, unless you're using different values now._

Clone/fork this GitHub repository and configure your GitHub repository like this:

**Service principal:**

Go to your GitHub repository then navigate to _Settings -> Secrets -> Actions -> New repository secret_

- Name: AZURE_CREDENTIALS_LA
- Secret: <<_Paste here the output of `az ad sp create-for-rbac` command from [step 2](#2-create-or-ask-someone-to-create-them-for-you-service-principals)_>>

**Azure subscription id:**

Go to your GitHub repository then navigate to _Settings -> Secrets -> Actions -> New repository secret_

- Name: SUBSCRIPTION_ID
- Secret: <<_Your Azure Subscription Id from [step 2](#2-create-or-ask-someone-to-create-them-for-you-service-principals)_>>

**SQL Server username:**

Go to your GitHub repository then navigate to _Settings -> Secrets -> Actions -> New repository secret_

- Name: SQL_USER
- Secret: <<_Admin user name you had selected for your SQL Server_>>

**SQL Server password:**

Go to your GitHub repository then navigate to _Settings -> Secrets -> Actions -> New repository secret_

- Name: SQL_PASS
- Secret: <<_Password of the admin user you had selected for your SQL Server_>>

### 4. Review and modify deploy parameters

File [`logic-app-resources/parameters.json`](/logic-app-resources/parameters.json) contains default values for:

- SQL Server connection object for Logic App (`sqlServerConnection`)
- Azure Storage Account connection object for Logic App (`azureBlobConnection`)
- Logic App name (`expenseReportLogicApp`)
- Integration Account name (`integrationAccount`)
- Azure Storage Container name for attachment files (`externalAttachmentStorageName`)
- Resource group name of the external resources (`externalResourceGroupName`)
- SQL Server address (`externalSqlServerAddress`)
- SQL Server database name (`externalSqlDatabaseName`)
- External REST API base URI (`externalExpenseReportsBaseURI`)

Review those parameter values and mofidy them if needed. Values for parameters

- `sqlServerConnection`,
- `azureBlobConnection`,
- `expenseReportLogicApp`, and
- `integrationAccount`

can be whatever, but all the rest (`externalXXXXXX` parameters) **must** be correct, otherwise deployment or the Logic App doesn't work correctly.

To find out how your resources are named in external resources resource group, run this command against resource group where they are deployed:

`az resource list -g <<EXTERNAL RESOURCES RESOURCE GROUP>> --query "[].{Name: name, Type: type}"`

Here you must replace `<<EXTERNAL RESOURCES RESOURCE GROUP>>` with the name of the actual resource group.

Then modify [`logic-app-resources/parameters.json`](/logic-app-resources/parameters.json) file, and replace sample values of `externalXXXX` in the file with actual values.

### 5. Update environment variables in GitHub Actions workflow

In file [`.github/workflows/logic-app-resources.yml`](/.github/workflows/logic-app-resources.yml), you must change the name of the target resource group if it's different from what you created in [step 1](#1-create-a-resource-group). Default value for the resource group is `samikomulainen-azuredemo2`.

```
env:
  RESOURCE_GROUP_NAME: <<YOUR RESOURCE GROUP NAME>>
```

If you previously used a different folder (`my-logic-app-resources`) to store your Bicep and parameter files, you should change the folder path here as well like this:

```
  TEMPLATE_PATH: my-logic-app-resources/template.bicep
  PARAMETERS_PATH: my-logic-app-resources/parameters.json
```

### 6. Start GitHub Actions workflow

Go to your GitHub repository then navigate to _Actions -> All workflows_.

Select **_Deploy Logic App and related resources_** workflow.

Click _Run workflow_.

Click the new _Run workflow_ button that appeared.

### 7. Test the deployed Logic App

Go to your GitHub repository then navigate to _Actions -> All workflows_.

Select **_Test Logic App_** workflow.

Click _Run workflow_.

Click the new _Run workflow_ button that appeared.
