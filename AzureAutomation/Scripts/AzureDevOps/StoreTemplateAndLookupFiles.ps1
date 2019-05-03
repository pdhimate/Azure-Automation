<# 
	Use this script to store all the ARM templates and Lookups to blobs using AzureDevOps/VSTS.
	This can also be run locally.
#>
param(
    [string] $ResourceGroupLocation = "Central India",
    [string] $ResourceGroupName,
    [string] $StorageAccountName # The storage account which is used to store the templates, lookups etc as Blobs
)
$ErrorActionPreference = 'Stop'
$VerbosePreference = 'Continue'

# Fetches the path of the root folder of the project
$RootFolderPath = (Get-Item $PSScriptRoot).Parent.Parent.FullName

## Include modules in the env variable
#$ModulePaths = @()
#$ModulePaths += (Resolve-Path($RootFolderPath + '/Modules'))
#$ModulePaths += $env:PSModulePath -split ';'
#$env:PSModulePath = $ModulePaths -join ';'

# Import hepler methods
$commonPsd = (Resolve-Path($RootFolderPath + '/Modules/AzureAutomation.Common/AzureAutomation.Common.psd1'))
Import-Module $commonPsd -Force -Verbose
$UtilitiesPsm = (Resolve-Path($RootFolderPath + '/Modules/AzureAutomation.Utilities/AzureAutomation.Utilities.psm1'))
Import-Module $UtilitiesPsm -Force -Verbose

# Store all templates to Blobs
$TemplatesDirectory = (Resolve-Path($RootFolderPath + "/templates"))
Push-ToStorageAccount -FilesDirectory $TemplatesDirectory `
    -StorageAccountName $StorageAccountName `
    -ResourceGroupLocation $ResourceGroupLocation `
    -StorageResourceGroupName $ResourceGroupName 

# Store all lookups to Blobs 
$TemplatesDirectory = (Resolve-Path($RootFolderPath + "/Lookups"))
Push-ToStorageAccount -FilesDirectory $TemplatesDirectory `
    -StorageAccountName $StorageAccountName `
    -ResourceGroupLocation $ResourceGroupLocation `
    -StorageResourceGroupName $ResourceGroupName 

