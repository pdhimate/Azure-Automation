<# 
	Use this script to store the templates and lookups to Blob Storage 
#>
param(
    [string] $ResourceGroupLocation = "Central India",
    [string] $ResourceGroupName = "azauto-rg-kajnfjniupiyush",
    [Parameter(Mandatory = $false)] [string] $TargetSubscriptionId, # The azure subscription where the  storage account will be hosted into.
    [string] $StorageAccountName = "azautostgazzzjsnfpiyush" # The storage account which is used to store the templates, lookups etc as Blobs
)

$ErrorActionPreference = 'Stop'
$RootFolderPath = (Get-Item $PSScriptRoot).Parent.Parent.FullName

# # Import AzureAz modules and enable aliases
# Import-Module Az
# Enable-AzureRmAlias

# Import helper modules
Import-Module (Resolve-Path($RootFolderPath + '/Modules/AzureAutomation.Common/AzureAutomation.Common.psm1')) -Force -Verbose
Import-Module (Resolve-Path($RootFolderPath + '/Modules/AzureAutomation.Utilities/AzureAutomation.Utilities.psm1')) -Force -Verbose

# Connect to Azure Subscription
Connect-Environment -SubscriptionId $TargetSubscriptionId 

# Invoke Store script
$StoreScript = (Resolve-Path($RootFolderPath + '/Scripts/AzureDevOps/StoreTemplateAndLookupFiles.ps1'))
$StoreScript = $StoreScript -replace ' ', '` ' 
$ResourceGroupLocation = $ResourceGroupLocation -replace ' ', '` ' # escape spaces in the location name
$Parameters = "-ResourceGroupName " + "$ResourceGroupName" + " -ResourceGroupLocation " + "$ResourceGroupLocation" + " -StorageAccountName " + "$StorageAccountName"
Write-Output "Parameters : "$Parameters
$Command = "$StoreScript $Parameters"
$Command = "& $Command"

Write-Output "Command : "$Command
Invoke-Expression -Command $Command

