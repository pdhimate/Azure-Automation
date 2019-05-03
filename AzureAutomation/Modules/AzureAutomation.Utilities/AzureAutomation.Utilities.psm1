<#
    [LOCAL]: Can be run locally only
    Attempts to get cached Azure context else connects to the Azure account
#>
function Connect-Environment {
    param(
        [Parameter(Mandatory = $false)] [string] $SubscriptionId
    )
    try {
        $RMContext = Get-AzureRmContext
        Write-Versbose $RMContext | Format-List
    }
    catch {
        Connect-AzureRmAccount 
    }

    # Set azure context to use the specified subscription, if any
    if ($SubscriptionId) {
        # Set-AzureRmContext -SubscriptionId $SubscriptionId
        Select-AzureRmSubscription -SubscriptionId $SubscriptionId
    }
}

<#
    Generates a Container level readonly SAS token
#>
Function Get-ContainerSAS {
    param(
        [string] $ContainerName,
        [object] $StorageAccountContext
    )
    $ContainerSasToken = ''
    do {
        # Generate SAS token with read permissions (preventing + signs)
        $ContainerSasToken = [string](New-AzureStorageContainerSASToken -Name $ContainerName `
                -Permission rl `
                -Context $StorageAccountContext `
                -StartTime (Get-Date).AddHours(-24) -ExpiryTime (Get-Date).AddHours(24))
    }while ([Uri]::UnescapeDataString($ContainerSasToken).Contains('+'))

    return $ContainerSasToken
}

<#
    Gets the raw file content of a file stored as a Blob
#>
function Get-BlobFileRaw {
    param (
        [Parameter(Mandatory = $true)] [string] $ContainerUrl, # base url of the lookup files container
        [Parameter(Mandatory = $true)] [string] $ContainerSasToken, # Container level SAS to donwload the lookup files
        [Parameter(Mandatory = $true)] [string] $BlobName, # Container level SAS to donwload the lookup files
        [Parameter(Mandatory = $true)] [string] $TempLocalDir   # Path of a temporary local directory to store the blob file before extracting content
    )
    # Check if temp local directory exists
    if (!(Test-Path -Path $TempLocalDir)) {
        New-Item -ItemType directory -Path $TempLocalDir
    }

    # Get file from blob and save it locally
    $sasUrl = $ContainerUrl + "/" + $BlobName + $ContainerSasToken
    $fileName = (Get-PseudoRandomId -Size 15) + $BlobName
    $filePath = $TempLocalDir + "/" + $fileName
    Invoke-WebRequest -Uri $sasUrl -OutFile $filePath
     
    # Get file content from the temp folder
    $rawFileContent = (Get-Content $filePath -raw)

    return $rawFileContent
}

<#
    Gets the Resource type csv file from a blob, as an object
#>
Function Get-BlobCsv {
    param(
        [Parameter(Mandatory = $true)] [string] $ContainerUrl, # base url of the lookup files container
        [Parameter(Mandatory = $true)] [string] $ContainerSasToken, # Container level SAS to donwload the lookup files
        [Parameter(Mandatory = $true)] [string] $BlobName, # Container level SAS to donwload the lookup files
        [Parameter(Mandatory = $true)] [string] $TempLocalDir   # Path of a temporary local directory to store the blob file before extracting content
    )
    $rawContent = Get-BlobFileRaw -ContainerUrl $ContainerUrl -ContainerSasToken $ContainerSasToken -BlobName $BlobName -TempLocalDir $TempLocalDir
    $csv = (ConvertFrom-CSV ($rawContent).ToString()) 

    return $csv
}


# Fetch Azure subscripiton from subscription name
function Get-AzureSubscription {
    param (
        [string] $SubscriptionName,
        [Hashtable] $Output 
    )
    Write-Output "Getting details for the Azure Subscription: $SubscriptionName"

    # Fetch Azure subscripiton ID from subscription name
    $AzureSubscription = Get-AzureRmSubscription | Where-Object { $_.Name.ToLowerInvariant() -eq $SubscriptionName.ToLowerInvariant() }
    if (!$AzureSubscription) {
        Write-ErrorOutput "Could not find a subscription with name : $SubscriptionName OR the current account does not have access to the subscription"
    }

    # Set output
    $Output.Id = $AzureSubscription.Id
    $Output.Name = $AzureSubscription.Name
    $Output.TenantId = $AzureSubscription.TenantId
    $Output.State = $AzureSubscription.State
}

<# 
    Logs in or switches to the specified subscription.
#>
function Switch-OrLoginToSubscription {
    param(
        [string] $AutomationAccountConnectionName, # The name of AutomationAccountConnection which has permissions (contributor) to deploy the resources on the target subscription
        [string] $SubscriptionId ,
        [Hashtable] $Output  # referenced parameter for output
    )
    Write-Output "Logging in/Switching to Azure Subscription : $SubscriptionId"
    if ([CommonConstants]::IsExecutingAsRunbook) {
        $servicePrincipalConnection = Get-AutomationConnection -Name $AutomationAccountConnectionName 
        Add-AzureRmAccount `
            -ServicePrincipal `
            -TenantId $servicePrincipalConnection.TenantId `
            -SubscriptionId $SubscriptionId `
            -ApplicationId $servicePrincipalConnection.ApplicationId `
            -CertificateThumbprint $servicePrincipalConnection.CertificateThumbprint 
    
        # Set Output properties
        # Copy-HashTable -InputHashTable $servicePrincipalConnection -OutputHashTable $Output
        $Output.TenantId = $servicePrincipalConnection.TenantId 
    }
    else {
        Connect-Environment -SubscriptionId $SubscriptionId
        $Output.TenantId = (Get-AzureRmContext).Tenant.Id 
    }
}

<#
    [LOCAL]: Can be run locally only
    Attempts to get cached Azure context else connects to the Azure account
#>
Function Connect-Environment {
    param(
        [Parameter(Mandatory = $false)] [string] $SubscriptionId
    )
    try {
        $RMContext = Get-AzureRmContext
        Write-Versbose $RMContext | Format-List
    }
    catch {
        Connect-AzureRmAccount 
    }

    # Set azure context to use the specified subscription, if any
    if ($SubscriptionId) {
        # Set-AzureRmContext -SubscriptionId $SubscriptionId
        Select-AzureRmSubscription -SubscriptionId $SubscriptionId
    }
}

<#
    Stores all the files in the specified local folder to Blob storage. 
    Creates a new Storage Account if not found.
#>
function Push-ToStorageAccount {
    param (
        [Parameter(Mandatory = $true)] [string] $FilesDirectory ,
        [Parameter(Mandatory = $true)] [string] $ResourceGroupLocation, # location of the resource group under which the storage account resides
        [Parameter(Mandatory = $true)] [string] $StorageAccountName, # Storage account which holds templates, lookups etc
        [Parameter(Mandatory = $true)] [string] $StorageResourceGroupName # name of resource group under which teh storage account resides
    )
    $StorageContainerName = (Split-Path $FilesDirectory -Leaf).ToLowerInvariant() # must be small case
    $StorageType = 'Standard_LRS'

    # Create a storage account name if none was provided
    $StorageAccount = (Get-AzureRmStorageAccount | Where-Object {$_.StorageAccountName -eq $StorageAccountName})

    # Create the storage account if it doesn't already exist
    if ($null -eq $StorageAccount ) {
        $rg = Get-ResourceGroup -ResourceGroupName $StorageResourceGroupName
        if ($null -eq $rg) {
            Write-ErrorOutput "Resource Group : $StorageResourceGroupName was not found" 
        }
        New-AzureRmResourceGroup -Location $ResourceGroupLocation -Name $StorageResourceGroupName -Force
        $StorageAccount = New-AzureRmStorageAccount -StorageAccountName $StorageAccountName -Type $StorageType -ResourceGroupName $StorageResourceGroupName -Location "$ResourceGroupLocation"
    }

    # Generate the value for artifacts location if it is not provided in the parameter file
    $ContainerUrl = $StorageAccount.Context.BlobEndPoint + $StorageContainerName
    Write-Output 'Artifacts location : '$ContainerUrl

    # Copy files from the local storage to the storage account container
    New-AzureStorageContainer -Name $StorageContainerName -Context $StorageAccount.Context -ErrorAction SilentlyContinue *>&1
    $ArtifactFilePaths = Get-ChildItem $FilesDirectory -Recurse -File | ForEach-Object -Process {$_.FullName}
    foreach ($SourcePath in $ArtifactFilePaths) {
        $FilePath = $SourcePath.Substring($FilesDirectory.length + 1)
        Set-AzureStorageBlobContent -File $SourcePath -Blob  $FilePath `
            -Container $StorageContainerName -Context $StorageAccount.Context -Force

        Write-Output "Copied : $FilePath"
    }
}


<#
    Gets a resource group or Creates a resource group if it doesn't exist.
#>
Function Get-OrCreateResourceGroup {
    param(
        [Parameter(Mandatory = $true)] [string] $ResourceGroupName,
        [Parameter(Mandatory = $true)] [string] $ResourceGroupLocation,
        [Parameter(Mandatory = $true)] [Hashtable] $ResourceGroupTags
    )
    $rg = Get-ResourceGroup -ResourceGroupName $ResourceGroupName

    if (!$rg) {
        # See: https://docs.microsoft.com/en-us/powershell/module/azurerm.resources/new-azurermresourcegroup?view=azurermps-6.13.0
        New-AzureRmResourceGroup -Location $ResourceGroupLocation -Name $ResourceGroupName -Tag $ResourceGroupTags
        $rg = Get-ResourceGroup -ResourceGroupName $ResourceGroupName 
    }

    return $rg
}


<#
    Returns a resource group, if it exists.
    null otherwise.
#>
Function Get-ResourceGroup {
    param(
        [Parameter(Mandatory = $true)] [string] $ResourceGroupName
    )
    $rg = Get-AzureRmResourceGroup -Name $ResourceGroupName -ErrorVariable notPresent -ErrorAction SilentlyContinue
    if ($notPresent) {
        return $null
    }
    return $rg
}
