#
# Module manifest for .ps1 files listed below. Each of these files contain a separate class.
# Generated by: Piyush Dhimate
# Generated on: 03/May/19
#

@{
    # Script module or binary module file associated with this manifest.
    RootModule        = 'AzureAutomation.Utilities.psm1'

    # Version of the module. Use this to track when the module was updated.
    ModuleVersion     = '1.0'
    
    # ID used to uniquely identify this module
    GUID              = '5D445E48-AA5A-4041-8CFE-F8D074373D2E'

    Description       = 'Comon AzureRm Utilities related PS functions'
    Author            = 'Piyush Dhimate'
    FunctionsToExport = @(
        'Connect-Environment',
        'Get-ContainerSAS',
        'Get-BlobFileRaw',
        'Get-BlobCsv',
        'Get-AzureSubscription',
        'Show-DeloymentOutput',
        'Switch-OrLoginToSubscription',
        'Push-ToStorageAccount',
        'Get-OrCreateResourceGroup',
        'Get-ResourceGroup'
    )

    RequiredModules   = @(
    )
		
    PrivateData       = @{
    }

    # Default prefix for commands exported from this module. Override the default prefix using Import-Module -Prefix.
    # DefaultCommandPrefix = ''
}