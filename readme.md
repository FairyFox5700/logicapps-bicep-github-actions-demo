# Introduction

The purpose of this repository is to demonstrate you three things:

- how to write an Azure Logic App that uses different data sources and combines their data,
- how to convert your Logic App and other resources into a parameterized Bicep template, and
- how to deploy your Bicep template to Azure using GitHub Actions

This repository has two parts:

- external resources (SQL Server database, storage accounts) that are required for the Logic App,
- and the actual Logic App (incl. connections to external resources and an integration account)

For more thorough explanation how this demo is organized from the Logic App point of view, please see [this document](/docs/demo_purpose.md).

# Recommended prerequisites

- Basic knowledge of [Azure resources (AZ-900 level)](https://aka.ms/AzureLearn_Fundamentals), especially:
  - [Storage accounts](https://docs.microsoft.com/en-us/learn/paths/az-104-manage-storage)
  - [SQL Server and databases](https://docs.microsoft.com/en-us/learn/paths/azure-sql-fundamentals)
- Basic knowledge of [Azure AD](https://docs.microsoft.com/en-us/azure/active-directory/fundamentals/active-directory-whatis) (especially [service principals](https://docs.microsoft.com/en-us/learn/modules/authenticate-azure-deployment-pipeline-service-principals))
- Basic knowledge of [Logic Apps](https://docs.microsoft.com/en-us/learn/paths/build-workflows-with-logic-apps)
- Basic knowledge of [Azure CLI tool](https://docs.microsoft.com/en-us/cli/azure)
- Basic knowledge of GitHub Actions ([1](https://docs.microsoft.com/en-us/learn/paths/automate-workflow-github-actions), [2](https://docs.microsoft.com/en-us/learn/paths/bicep-github-actions))
- Basic knowledge of [ARM templates](https://docs.microsoft.com/en-us/learn/paths/deploy-manage-resource-manager-templates) and [Bicep language](https://docs.microsoft.com/en-us/azure/azure-resource-manager/bicep)

_Not everything I've linked above is needed, but if you don't understand something please study the linked material carefully._

# Deploying external resources

Guide for deploying external resources can be found [here](/docs/extenal-resources-deploy.md).

Do this before other steps.

# Creating a Bicep template from your Logic App and writing a GitHub Actions workflow

Guide how to convert your own Logic App (you've developed on Azure portal according to my instructions on the video or [the application logic definition](/docs/demo_purpose.md)) and its required resources into a Bicep template, and write a GitHub Actions workflow for deploying the template using GitHub Actions can be found [here](/docs/from-logicapp-to-bicep.md).

# Deploying Logic App and its required resources as Bicep template using GitHub Actions

Guide for deploying a ready-made Logic App and its required resources as Bicep template can be found [here](/docs/logic-app-resources-deploy.md).

You can follow this guide even if you've prepared a Bicep template and a GitHub Actions workflow according to my instructions at the previous step.

# Future improvements

Some ideas how this demo could be improved:

- More secure authentication methods
- Authentication for the external REST API
- Getting rid of Bicep warnings
- Adding an alternative CI/CD pipeline: Azure DevOps pipeline
- Use KeyVault for storing credentials
- Define Logic App as a separate file/module
