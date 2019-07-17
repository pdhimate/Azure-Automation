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
2. Host the [Deploy.ps1](https://github.com/pdhimate/Azure-Automation/blob/master/AzureAutomation/Scripts/Deploy.ps1) script as an Azure Runbook in an Automation account. 
    * Ensure that you have set the **$ExecutionEnvironment** variable to **Runbook**
    * Ensure that you have set the **$StorageAccountName** variable to the Storage Account name used in step 1.
3. Import the zipped (modules)[https://github.com/pdhimate/Azure-Automation/tree/master/AzureAutomation/Modules] in the Automation account.
3. Assign appropriate permissions for the Runbook to be able to deploy resources in the target azure subscription. 

You can now run the runbook with the required parameters to deploy the resource.

## Supported Resources list
- Virtual network [[Template]](https://github.com/pdhimate/Azure-Automation/blob/master/AzureAutomation/Templates/nested/vnet/template.json)

## Adding new Resources
### Step 1: Add the ARM template files (refer existing files for ease)
1. Create a **template.json** file for your resource, which would contain the ARM template for your resource. 
2. Create a **link.json** file which would contain the nested template link which would eventually be inserted in the main template's resources section by the Deploy Script.
3. Create a **variable.json** file which would contain all the vairables being passed to the nested template from the main template.
4. Create a new folder for your resource say **cosmosdb** (small case, no space), add the 3 files created above in it and add the fodler under the [nested templates folder](https://github.com/pdhimate/Azure-Automation/blob/master/AzureAutomation/Templates/nested)

### Step 2: Update lookups
Goto the [lookups/Resources.csv](https://github.com/pdhimate/Azure-Automation/blob/master/AzureAutomation/lookups/Resources.csv) file and add a new entry for you resource, say *Cosmos Db, cdb, 63*, for name, short code and max charater limit (azure's limit for maximum length of the name)

### Step 3: Update Common Constants.ps1
Goto the [CommonConstants.ps1](https://github.com/pdhimate/Azure-Automation/blob/master/AzureAutomation/Modules/AzureAutomation.Common/CommonConstants.ps1) file and update the **$ResourceTypeToTemplateFolderMap** variable with the mapping for the template and lookup added in step 1 and 2. Note that the names should match here.

### Step 4: Deploy the updates
1. Zip the [AzureAutomation.Common](https://github.com/pdhimate/Azure-Automation/tree/master/AzureAutomation/Modules/AzureAutomation.Common) and import it in the Azure Automation Account. You may update the version in the psd file for your reference.
2. Run the [StoreTemplateAndLookupFiles.ps1](https://github.com/pdhimate/Azure-Automation/blob/master/AzureAutomation/Scripts/Local/StoreTemplateAndLookupFiles.ps1) script to upload the updated templates and lookups to an Azure Blob Storage Account.

### Step 5: Test
Try to deploy the newly added template using the name and other parameters for the deploy runbook.
