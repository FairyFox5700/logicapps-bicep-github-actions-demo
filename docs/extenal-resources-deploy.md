# Deploying external resources

This demo uses some external resources that must be deployed before developing a Logic App.

I've included instructions how to do [deploy manually (using Azure CLI and sqlcmd)](#manual-deploy-using-azure-cli-and-sqlcmd) or [using GitHub Actions workflow](#deploy-using-github-actions-workflow).

## Manual deploy (using Azure CLI and sqlcmd)

### 1. Azure CLI login

Type [`az login`](https://docs.microsoft.com/en-us/cli/azure/authenticate-azure-cli) and follow instructions. A browser window/tab is opened and you must fill your credentials (Azure portal username and password).

If you have more than one active Azure subscriptions, you must choose the correct one with [`az account set -s <<YOUR SUBSCRIPTION ID>>`](https://docs.microsoft.com/en-us/cli/azure/manage-azure-subscriptions-azure-cli#change-the-active-subscription)

### 2. Create a resource group using Azure CLI

[`az group create --name <<YOUR RESOURCE GROUP NAME>> --location <<YOUR RESOURCE GROUP LOCATION>>`](https://docs.microsoft.com/en-us/cli/azure/group?view=azure-cli-latest#az-group-create)

You must at least specify a resource group name. You must also specify a resource group location (e.g. `westeurope`) if you haven't set a default location.

### 3. Review deploy parameters

File [`external-resources/parameters.json`](/external-resources/parameters.json) contains default values for:

- Azure Storage Account name for attachments (`attachment_storage_name`)
- Azure Storage Account name for expense report files (i.e. a fake REST API) (`expensereports_storage_name`)
- Azure SQL Server name (`sqlserver_name`)
- Azure SQL Server database name (`sqlserver_database_name`)

Review those parameter values and modify them if needed.

Please notice that extra characters are added to the end of storage accounts and SQL server to make them globally unique (because Azure doesn't allow duplicate storage account or SQL Server names).

N.B. Bicep file [`external-resources/template.bicep`](/external-resources/template.bicep) contains also secret parameters for SQL Server user name and password. For security reasons those are not given in the parameter file, but you must give them yourself when running a deploy command.

### 4. Validate Bicep file and deploy resources defined in the file

Do syntax check for a Bicep file:

`az bicep build -f external-resources/template.bicep`

If there are errors or warnings after running the previous command, you should check those issues before proceeding to the next step.

Validate whether a template is valid at resource group:

`az deployment group validate -f external-resources/template.bicep -g <<YOUR RESOURCE GROUP NAME>> --mode Complete -p external-resources/parameters.json -p sqlUser=<<YOUR SQL SERVER USERNAME>> sqlPass=<<YOUR SQL SERVER PASSWORD>>`

If there are errors or warnings after running the previous command, you should check those issues before proceeding to the next step.

Do deploy:

`az deployment group create -f external-resources/template.bicep -g <<YOUR RESOURCE GROUP NAME>> --mode Complete -p external-resources/parameters.json -p sqlUser=<<YOUR SQL SERVER USERNAME>> sqlPass=<<YOUR SQL SERVER PASSWORD>>`

### 5. Copy attachment files to Azure Blob Storage

After deployment has finished, you can copy files recursively from [`external-resources/attachments`](/external-resources/attachments) to Azure Blob Storage using this command:

`az storage copy -s "external-resources/attachments/*" -d "https://<<ATTACHMENT STORAGE NAME>>.blob.core.windows.net/files" --recursive`

Please notice that your must specify the name of the Azure Storage Account for attachments (if you didn't change the parameters during deploy, it begins with `myattachments` with some random characters added to the end of the name).

### 6. Copy expense report files to Azure Blob Storage

`az storage copy -s "external-resources/expense-items/*" -d "https://<<EXPENSE STORAGE NAME>>.blob.core.windows.net/api"`

Please notice that your must specify the name of the Azure Storage Account for expense reports (if you didn't change the parameters during deploy, it begins with `myexpensereports` with some random characters added to the end of the name).

### 7. Add a temporary firewall rule for SQL Server

In order to access (and run SQL commands against Azure SQL Server), we must add a temporary firewall rule for Azure SQL Server.

Add a firewall rule for SQL Server:

`az sql server firewall-rule create -g <<YOUR RESOURCE GROUP NAME>> -s <<YOUR SQL SERVER NAME>> -n temporaryrule --start-ip-address <<YOUR IP ADDRESS>> --end-ip-address <<YOUR IP ADDRESS>>`

### 8. Create database table and insert data using sqlcmd

For this step, you must download [_sqlcmd_](https://docs.microsoft.com/en-us/sql/tools/sqlcmd-utility) utility to run SQL scripts against Azure SQL Servers databases.

Then you must check your Azure SQL Server and database name (if you didn't change the parameters during deploy, database name is `myuserdb` and SQL Server name begins with `myuserdbserver` with some random characters added to the end of the name).

Then run this command to insert tables and rows into your database:

`sqlcmd -S <<YOUR SQL SERVER NAME>>.database.windows.net -U <<YOUR SQL SERVER USERNAME>> -P <<YOUR SQL SERVER PASSWORD>> -d <<YOUR SQL SERVER DATABASE NAME>> -i external-resources/database/create_data.sql`

### 9. Remove the temporary firewall rule for SQL Server

After running SQL commands against Azure SQL Server, we don't need to use it from our PC, so we can delete our temporary firewall rule.

`az sql server firewall-rule delete -g <<YOUR RESOURCE GROUP NAME>> -s <<YOUR SQL SERVER NAME>> -n temporaryrule`

## Deploy using GitHub Actions workflow

If you like to use CI/CD based approach to deploy external resources using GitHub Actions workflow, here's what you need to do:

### 1. Create a resource group

Create a resource group for external resources either using Azure Portal or Azure CLI (_see [instructions for creating a resource group using Azure CLI](#2-create-a-resource-group-using-azure-cli)_).

### 2. Create (or ask someone to create them for you) service principals

In order to use GitHub Actions to deploy Azure resources, you have to have a [service principal](https://learn.microsoft.com/en-us/cli/azure/create-an-azure-service-principal-azure-cli), which allows you to authenticate against Azure and run deploy operations without having to manually provide your credentials.

When creating a service principal, make sure it has contributor rights to the resource group you created earlier in [step 1](#1-create-a-resource-group).

_N.B. If you haven't done [Azure login from your CLI](#1-azure-cli-login), you must do it first before running other Azure CLI commands._

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

Store this output because you'll need it later on.

### 3. Clone/fork repository and configure GitHub repository secrets

Clone/fork this GitHub repository and configure your GitHub repository like this:

**Service principal:**

Go to your GitHub repository then navigate to _Settings -> Secrets -> Actions -> New repository secret_

- Name: AZURE_CREDENTIALS_EXT
- Secret: <<_Paste here the output of `az ad sp create-for-rbac` command_>>

**Azure subscription id:**

Go to your GitHub repository then navigate to _Settings -> Secrets -> Actions -> New repository secret_

- Name: SUBSCRIPTION_ID
- Secret: <<_Your Azure Subscription Id from [step 2](#2-create-or-ask-someone-to-create-them-for-you-service-principals)_>>

**SQL Server username:**

Go to your GitHub repository then navigate to _Settings -> Secrets -> Actions -> New repository secret_

- Name: SQL_USER
- Secret: <<_Admin user name you have selected for your SQL Server_>>

**SQL Server password:**

Go to your GitHub repository then navigate to _Settings -> Secrets -> Actions -> New repository secret_

- Name: SQL_PASS
- Secret: <<_Password of the admin user you have selected for your SQL Server_>>

### 4. Review deploy parameters

File [`external-resources/parameters.json`](/external-resources/parameters.json) contains default values for:

- Azure Storage Account name for attachments (`attachment_storage_name`)
- Azure Storage Account name for expense report files (i.e. a fake REST API) (`expensereports_storage_name`)
- Azure SQL Server name (`sqlserver_name`)
- Azure SQL Server database name (`sqlserver_database_name`)

Review those parameter values and modify them if needed.

Please notice that extra characters are added to the end of storage accounts and SQL server to make them globally unique (because Azure doesn't allow duplicate storage account or SQL Server names).

### 5. Update environment variables in GitHub Actions workflow

In file [`.github/workflows/external-resources.yml`](/.github/workflows/external-resources.yml), you must change the name of the target resource group if it's different from what you created in [step 1](#1-create-a-resource-group). Default value for the resource group is `samikomulainen-azuredemo1`.

```
env:
  RESOURCE_GROUP_NAME: <<YOUR RESOURCE GROUP NAME>>
```

### 6. Start GitHub Actions workflow

Go to your GitHub repository then navigate to _Actions -> All workflows_.

Select **_Deploy external resources_** workflow.

Click _Run workflow_.

Click the new _Run workflow_ button that appeared.

## Deployment troubleshooting

### Resource type namespaces not registered

If you're using a subscription where you haven't registered to use some resource type namespaces, you might get errors messages like these:

```
The subscription is not registered to use namespace 'Microsoft.Sql'. See https://aka.ms/rps-not-found for how to register subscriptions.
```

```
The subscription is not registered to use namespace 'Microsoft.Storage'. See https://aka.ms/rps-not-found for how to register subscriptions.
```

In that case, go [here](https://learn.microsoft.com/en-us/azure/azure-resource-manager/troubleshooting/error-register-resource-provider?tabs=azure-cli) and look for examples how to check and register namespaces.

If namespace 'Microsoft.Sql' isn't registered to use, you can register it by running this command:

`az provider register --namespace Microsoft.Sql`

If namespace 'Microsoft.Storage' isn't registered to use, you can register it by running this command:

`az provider register --namespace Microsoft.Storage`

After registration is complete, you can try running deploy scripts again (manually or using GitHub Actions).

### Timeout during SQL script run

When I was testing my deployment scripts, I got this error during SQL script run. This is probably due to SQL Server or database not yet available (for running SQL scripts) even though deployment has already finished.

![Timeout during SQL script run](/docs/images/sql_error.jpg)

If you get an error like this, I recommend running the deployment again.
