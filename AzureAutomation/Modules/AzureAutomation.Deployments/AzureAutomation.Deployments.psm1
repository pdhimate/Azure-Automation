<#
    Dumps a well-formatted output to the Output Stream.
    JSON Outputs of Deployment commands like New-AzureRmResourceGroupDeployment, New-AzureRmResourceGroup.
#>
function Show-DeloymentOutput {
    param (
        [object]$output
    )
    Write-Output "=============================================================="
    Write-Output "Deployment Output : " $output
    Write-Output "=============================================================="
}

<#
    Uses the specified TargetSubscriptionName OR a set of parameters to determine the Target Azure Subscripiton Id
#>
function Resolve-TargetAzureSubscriptionId {
    param (
        [string] $TargetSubscriptionName,
        [Hashtable] $Output
    )
    $targetAzureSubscriptionId = ""
    # If taregt subscription name was specified
    if ($TargetSubscriptionName) {
        Write-Output "Fetch Azure subscription Id for the name : $TargetSubscriptionName"
        $azureSubscriptionOutput = New-Object -TypeName Hashtable
        Get-AzureSubscription -SubscriptionName $TargetSubscriptionName -Output $azureSubscriptionOutput
        $targetAzureSubscriptionId = $azureSubscriptionOutput.Id
    }
    # else try to use the first accessible subscription for deployment
    else {
        
        # If multiple subscriptions are accessible show the error 
        $allSubscriptions = Get-AzureRmSubscription
        if ($allSubscriptions -and ($allSubscriptions.Length -gt 1)) {
            Write-ErrorOutput "The context has access to multiple subscriptions. Please specify the TargetSubscription to deploy the resources to"
        }

        $firstSubscription = $allSubscriptions[0]
        $firstSubscriptionName = $firstSubscription.Name
        Write-Output "Got details for Azure subscription for the name : $firstSubscriptionName"
        $targetAzureSubscriptionId = $firstSubscription.Id
    }

    # Set output
    $Output.TargetAzureSubscriptionId = $targetAzureSubscriptionId
}

<#
    1. Generates names for the resource types.
    2. Any other business logic may be added here. 
    
    The returned object is passed to the main.json template
#>
function Get-ResourceConfigs {
    param (
        [Parameter(Mandatory = $true)] [string[]] $ResourceTypes, # Resource Types/Names
        [Parameter(Mandatory = $true)] [string] $ContainerUrlForLookups, # base url of the lookups Container
        [Parameter(Mandatory = $true)] [string] $SasForLookupsContainer ,
        [Parameter(Mandatory = $true)] [string] $TempLocalDir   # Path of a temporary local directory to store the blob file before extracting content
    )
    # A Constant prefix to all the generated names
    $NamePrefix = 'azauto'

    # Get Resources CSV 
    $ResourcesCsv = Get-BlobCsv -ContainerUrl $ContainerUrlForLookups -ContainerSasToken $SasForLookupsContainer -BlobName 'Resources.csv' -TempLocalDir $TempLocalDir
 
    # Generate names for each resource type
    $ResourceConfigs = New-Object -TypeName Hashtable
    foreach ($resource in $ResourceTypes) {
        # Get resources row from csv
        $resourceRow = Get-ResourceRow -ResourcesCsv $ResourcesCsv -Resource $resource
        $resourceShortCode = $resourceRow."Short Code"
        $resourceCharLimit = [int]$resourceRow."Name Max Char Limit" # max length for valid name for the resource
      
        # Generate a resource name
        $randomId = Get-PseudoRandomId -Size 20
        $ResourceNameWithoutAD = ""
        $ResourceConfigs[$resource] = New-Object -TypeName Hashtable 
        $ResourceName = $NamePrefix + "-" + $resourceShortCode + "-" + $randomId # default

        # Override default name, according to business logic or azure naming restrictions
        switch ($resource) {
            "Storage Account" {
                # no dashes
                $ResourceName = $NamePrefix + $resourceShortCode + $randomId
            }
        }
        
        # Reduce the name if it is more than the limit
        $ResourceName = Get-TrimmedString -InputString $ResourceName -MaxLength $resourceCharLimit

        # Set Resources Config. this will be passed on to the main template 
        # E.g. $ResourceConfigs."Virtual Network".name = azauto-vn-piyushpiyushabsj
        $ResourceConfigs[$resource]['name'] = $ResourceName
    } 
    
    return $ResourceConfigs
}


# Gets the row corresponding to teh specified Resource Type
function Get-ResourceRow {
    param (
        [PSCustomObject] $ResourcesCsv,
        [string] $Resource
    )

    $resourceRow = $ResourcesCsv | Where-Object {$_.("Name".ToLowerInvariant()) -eq $Resource.ToLowerInvariant()}
    if ($null -eq $resourceRow ) {
        Write-ErrorOutput "Could not find the Resource type/name : $Resource"
    }
    return $resourceRow
}
