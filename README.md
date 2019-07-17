# Azure Automation
An automation framework built using Powershell and ARM templates to automate deployments to Azure.

## Features
- Custom, unique naming convention for each delpoyed resource
- Separate template for each resource (or groups of resources)
- Dynamically created main template depeding on the resources selected to deploy.
- Separate module to contain scriptsused commonly
- In-script provision to run the script in an Azure Runbook or on local Powershell
- Ability to be hosted on VSTS/Azure DevOps pipeline.

## Hosting on Azure
To host the framework on Azure:
1. Use the [StoreTemplateAndLookupFiles.ps1](https://github.com/pdhimate/Azure-Automation/blob/master/AzureAutomation/Scripts/Local/StoreTemplateAndLookupFiles.ps1) script to upload the templates and lookups to an Azure Blob Storage Account. Note down the name of the account.
2. Host the [Deploy.ps1](https://github.com/pdhimate/Azure-Automation/blob/master/AzureAutomation/Scripts/Deploy.ps1) script as an Azure Runbook. 
    * Ensure that you have set the **$ExecutionEnvironment** variable to **Runbook**
    * Ensure that you have set the **$StorageAccountName** variable to the Storage Account name used in step 1.
3. Assign appropriate permissions for the Runbook to be able to deploy resources in the target azure subscription. 

You can now run the runbook with the required parameters to deploy the resource.

## Supported Resources list
- Virtual network [[Template]](https://github.com/pdhimate/Azure-Automation/blob/master/AzureAutomation/Templates/nested/vnet/template.json)
