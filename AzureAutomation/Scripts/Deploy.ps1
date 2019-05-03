<#
    The script that will deploy the resources.
    This can be run locally as well as a Runbook. PLease set the ExecutionEnvironment variable below accordingly.
#>

param(
    ##############################
    # Parameters required for a resource deployment
    ##############################
    [Parameter(Mandatory = $false)] [string] $ResourceGroupLocation = "Central India", # E.g. "Central India",
     
    # The Resource names/types to be deployed. See lookups/Resources.csv .
    [Parameter(Mandatory = $false)] [string[]] $ResourceTypes = @("Virtual Network"), 
     
    # The name of the Azure Subscription where the resource needs to be deployed. Can be null if account has access to only 1 subscription
    [Parameter(Mandatory = $false)] [string] $TargetSubscriptionName,
     
    ##############################
    # Parameters for overriding 
    ##############################
    # User specified name of the resource group to deploy the resources to, if any
    [Parameter(Mandatory = $false)] [string] $ResourceGroupName 
)
# Global Try catch block to take care of any error 
try {

    #  Init : Hard-coded
    $ErrorActionPreference = 'Stop'
    $VerbosePreference = 'Continue'
    $ExecutionEnvironment = "Local" # Allows to switch between executing Local or as a Runbook
    $StorageAccountName = "azautostgazzzjsnfpiyush"  # The name of the Storage account which stores the templates and lookup files as Blobs
    $AutomationAccountConnectionName = "AzureRunAsConnection" # Only needed when running as Runbook. This connection must be contributor for current as well as target subscriptions
    $MainTemplateFileName = 'main.json' # should be at the root of the blob container
    $TemplatesContainerName = 'templates' # must be small case
    $LookupsContainerName = 'lookups'
    $NestedTemplateFolderName = 'nested' 
    $LocalDir = 'C:\Temp' # path to store temporary files during deployment
    Write-Output "Init complete."

    # Validations. 
    if (!$ResourceTypes -or $ResourceTypes.Count -eq 0) {
        Write-ErrorOutput "Resources must must be specified."
    }
    Write-Output "Resource types to deploy : $ResourceTypes"
    Write-Output "Validations complete."

    # Import helper methods modules by calling the func. 
    # These modules need to be uploaded as modules in the Automation Account if running this as a Runbook. Upload the Modules/*.zip files
    Write-Output "Importing helper modules for the Execution Environment : $ExecutionEnvironment"
    if ($ExecutionEnvironment -eq "Runbook") {
        Import-Module AzureAutomation.Common
        Import-Module AzureAutomation.Utilities
        Import-Module AzureAutomation.Deployments
    }
    else {
        $RootFolderPath = (Get-Item $PSScriptRoot).Parent.FullName
        $ModulePaths = @()
        $ModulePaths += (Resolve-Path($RootFolderPath))
        $ModulePaths += $env:PSModulePath -split ';'
        $env:PSModulePath = $ModulePaths -join ';'
        $commonClassesPsd = (Resolve-Path($RootFolderPath + '/Modules/AzureAutomation.Common/AzureAutomation.Common.psd1'))
        Import-Module $commonClassesPsd -Force -Verbose
        $UtilitiesPsm = (Resolve-Path($RootFolderPath + '/Modules/AzureAutomation.Utilities/AzureAutomation.Utilities.psm1'))
        Import-Module $UtilitiesPsm -Force -Verbose
        $DeploymentsPsm = (Resolve-Path($RootFolderPath + '/Modules/AzureAutomation.Deployments/AzureAutomation.Deployments.psm1'))
        Import-Module $DeploymentsPsm -Force -Verbose
    }
    Write-Output "Imported helper modules."

    #  Init : Dynamic
    # Cache the execution environment for other scripts/modules to determine
    [CommonConstants]::ExecutionEnvironment = $ExecutionEnvironment  
    
    # Get Template Folder names of the resources to deploy. This should match with the ones in the Templates/nested folder. E.g @("cosmos","vnet")
    $ResourceTypeToTemplateFolderMap = [CommonConstants]::ResourceTypeToTemplateFolderMap
    $Templates = @() 
    foreach ($resourceType in $ResourceTypes) {
        # Add template folder name for the resource, used in blob storage
        $templateFolderName = $ResourceTypeToTemplateFolderMap[$resourceType].TemplateFolderName
        if ($templateFolderName) {
            $Templates += $templateFolderName
        }
    }
    if ($null -eq $Templates -or 0 -eq $Templates.Count) {
        Write-ErrorOutput "No nested templates could be found to deploy, for the specified Resources : $ResourceTypes"
    }
    Write-Output "Templates to deploy : $Templates"

    # Login/switch to the target Azure Subscription
    $loginOutput = New-Object -TypeName Hashtable
    Switch-OrLoginToSubscription -AutomationAccountConnectionName $AutomationAccountConnectionName -SubscriptionId $targetAzureSubscriptionId `
        -Output $loginOutput
    $tenantId = $loginOutput.TenantId

    # Determine the target Azure Subscription Id
    $targetAzureSubscriptionIdOutput = New-Object -TypeName Hashtable
    Resolve-TargetAzureSubscriptionId -TargetSubscriptionName $TargetSubscriptionName -Output $targetAzureSubscriptionIdOutput
    $targetAzureSubscriptionId = $targetAzureSubscriptionIdOutput.TargetAzureSubscriptionId
    
    # Get storage account
    $StorageAccount = (Get-AzureRmStorageAccount | Where-Object {$_.StorageAccountName -eq $StorageAccountName})
    if ($null -eq $StorageAccount ) {
        Write-ErrorOutput "Storage account : $StorageAccountName could not be found in the current subscription"
    }
    $ContainerUrlForTemplates = $StorageAccount.Context.BlobEndPoint + $TemplatesContainerName
    $SasForTemplatesContainer = Get-ContainerSAS -ContainerName $TemplatesContainerName -StorageAccountContext $StorageAccount.Context

    # Get main template file and save it locally
    Write-Output "Getting main template from container blob..."
    $MainTemplateSASUrl = $ContainerUrlForTemplates + "/" + $MainTemplateFileName + $SasForTemplatesContainer
    Invoke-WebRequest -Uri $MainTemplateSASUrl -OutFile ($LocalDir + "/" + $MainTemplateFileName)
    $TemplateFile = Join-Path -Path $LocalDir -ChildPath $MainTemplateFileName
    Write-Output "Stored main template locally : $TemplateFile"

    # Get JSON contained in the Main template file 
    $TemplateFileJSON = Get-Content $TemplateFile -raw | ConvertFrom-Json

    # Fetch all nested resources link and variable files 
    Write-Output "Getting nested template links from container blob..."
    $resources = @() # resources array in the main template
    foreach ($templateFolderName in $Templates) {
        $blobBaseUrl = $ContainerUrlForTemplates + "/" + $NestedTemplateFolderName + "/" + $templateFolderName  

        # Get nested template's link file contents
        $nestedTemplateFileContent = Get-BlobFileRaw -ContainerUrl $blobBaseUrl -ContainerSasToken $SasForTemplatesContainer -BlobName "link.json" -TempLocalDir $LocalDir
        $nestedTemplateLinkJSON = $nestedTemplateFileContent | ConvertFrom-Json
        # Insert it into resources array
        $resources += $nestedTemplateLinkJSON

        # Get nested template's variable file contents
        $nestedTemplateFileContent = Get-BlobFileRaw -ContainerUrl $blobBaseUrl -ContainerSasToken $SasForTemplatesContainer -BlobName "variable.json" -TempLocalDir $LocalDir
        $nestedTemplateVariableJSON = $nestedTemplateFileContent | ConvertFrom-Json
        # Insert it into variables array
        $variablePropertyName = $templateFolderName + "Config" # E.g. cosmosConfig, vnetConfig . Such naming convention has been used in the templates
        $TemplateFileJSON.variables | Add-Member @{ $variablePropertyName = $nestedTemplateVariableJSON }
    }

    # Insert the nested resources links and variables into the main template
    $TemplateFileJSON.resources = $resources
    Write-Output "Updated resources and variables in the main template"

    # Save the dynamically created MainTemplate file locally
    New-Item -ItemType directory -Path $LocalDir -Force 
    $MainTemplateFileToDeploy = $LocalDir + "/main-dynamic.json"
    $unescapedJson = $TemplateFileJSON | ConvertTo-Json -Depth 50 | ForEach-Object { [System.Text.RegularExpressions.Regex]::Unescape($_) }
    $unescapedJson | Out-File $MainTemplateFileToDeploy 
    Write-Output "Saved the main template to deploy, locally : $MainTemplateFileToDeploy"
 
    # Generate ResourceConfigs (names etc). This will be passed on to the main template
    $ContainerUrlForLookups = $StorageAccount.Context.BlobEndPoint + $LookupsContainerName
    $SasForLookupsContainer = Get-ContainerSAS -ContainerName $LookupsContainerName -StorageAccountContext $StorageAccount.Context
    $ResourceConfigs = Get-ResourceConfigs -ResourceTypes $ResourceTypes `
        -ContainerUrlForLookups $ContainerUrlForLookups `
        -SasForLookupsContainer $SasForLookupsContainer `
        -TempLocalDir $LocalDir

    # Cast each nested level into a hashtable otherwise the Deploy command fails to properly serialize this to JSON 
    # and ultimately the main template fails to find nested properties
    Write-Output "Casting resource configs.. "
    $ResourceConfigsHashed = ConvertTo-NestedHashTables -TargetHashTable $ResourceConfigs

    # Replace Resource Type with template folder name which is used by main template to set resource level parameters
    # Currently we have template folder name at depth 2, hence 2 for loops suffice
    $rc = New-Object -TypeName Hashtable
    foreach ($kvp1 in $ResourceConfigsHashed.GetEnumerator()) {
        # Get template folder name from mapping
        $templateFolderName = $ResourceTypeToTemplateFolderMap[$kvp1.Name].TemplateFolderName
        if ($null -eq $templateFolderName) {
            Write-ErrorOutput "Could not find template folder for : " + $kvp1.Name + " in $ResourceTypeToTemplateFolderMap"
        }
        # Add to generated names. 
        # E.g. $rc.cosmos.name = azauto-cdb-mjskvntwuaiptuzlixyopiyushd
        # E.g. $rc.vnet.name = azauto-vn-iejvorksmhimsheotujspiyushd
        $rc[$templateFolderName] = [Hashtable]$kvp1.Value
    }

    # Set main template parameters, we have so far
    Write-Output "Setting up parameters for the template..."
    $Parameters = New-Object -TypeName Hashtable
    $Parameters['_artifactsLocation'] = $ContainerUrlForTemplates
    $Parameters['_artifactsLocationSasToken'] = $SasForTemplatesContainer
    $Parameters['tenantId'] = $tenantId

    # Create or update the resource group using the specified template file and template parameters file
    if (!$ResourceGroupName) {
        $resourceGroupTypeKey = "Resource Group"  # from Lookup/Resources.csv 
        Write-Output "Generating a Resource Group name..."
        $ResourceGroupConfig = Get-ResourceConfigs -ResourceTypes @($resourceGroupTypeKey) `
            -ContainerUrlForLookups $ContainerUrlForLookups `
            -SasForLookupsContainer $SasForLookupsContainer `
            -TempLocalDir $LocalDir

        if ($null -eq $ResourceGroupConfig[$resourceGroupTypeKey]) {
            Write-ErrorOutput "Could not generate config for : $resourceGroupTypeKey"
        }
        $ResourceGroupName = $ResourceGroupConfig[$resourceGroupTypeKey].name
    }

    # Set dynamic properties in resource configs
    Write-Output "Setting dynamic properties in Resources Config template parameter..."
    foreach ($kvp1 in $ResourceConfigsHashed.GetEnumerator()) {
        # Get template folder name from mapping
        $templateFolderName = $ResourceTypeToTemplateFolderMap[$kvp1.Name].TemplateFolderName
        if ($null -eq $templateFolderName) {
            Write-ErrorOutput "Could not find template folder for : " + $kvp1.Name + " in $ResourceTypeToTemplateFolderMap"
        }
   
        # Set mandatory dynamic properties
        $rc[$templateFolderName]."laWorkspaceResourceId" = $laWorkspace.ResourceId
    
        # Set custom dynamic properties, as required by certain resources
        switch ($templateFolderName) {
            "vnet" { 
                # doesnot need any
            }
        }

        # Override the generated resource name if the user has specified it
        if ($ResourceName) {
            Write-Output "Overriding Resource Name with : $ResourceName"
            $rc[$templateFolderName]."name" = $ResourceName
        }
    }

    # Set template parameters dependent on the current Azure subscription
    $Parameters['resourceConfigs'] = [Hashtable]$rc

    # Check if resource group exists for the resource being deployed, if not create it
    # Set Resource Group tags, if needed
    $ResourceGroupTags = @{
        ProvisionedBy = "AzureAutomation";
    }
    Write-Output "Creating resource group, if it does not exist"
    Get-OrCreateResourceGroup -ResourceGroupName $ResourceGroupName -ResourceGroupLocation $ResourceGroupLocation -ResourceGroupTags $ResourceGroupTags

    # Create the resources
    Write-Output "Deploying resources..."
    $deploymentName = ((Get-ChildItem $TemplateFile).BaseName + '-' + ((Get-Date).ToUniversalTime()).ToString('MMdd-HHmm'))
    $jsonOutput = New-AzureRmResourceGroupDeployment -Name  $deploymentName `
        -ResourceGroupName $ResourceGroupName `
        -TemplateFile $MainTemplateFileToDeploy `
        -TemplateParameterObject $Parameters `
        -Force -Verbose `
        -ErrorVariable TemplateErrorMessages -DeploymentDebugLogLevel All
    
    # Show deployment output
    Show-DeloymentOutput -output $jsonOutput
    $Success = ($jsonOutput -and $jsonOutput.ProvisioningState -eq "Succeeded")

    # Show errors, if any
    if ($TemplateErrorMessages) {
        Write-Output "Template deployment returned the following errors: $TemplateErrorMessages"
    }
}
# Global catch for any error
catch {
    $ErrorMessages = $_
    $Success = $false
}

# Showed error messages if deployment failed, might as well send email notification or something
if (!$Success) {
    Write-Output $ErrorMessages
    Write-Error $ErrorMessages
}