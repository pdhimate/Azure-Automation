<#
Holds Constants/Statics that are needed anywhere.
#>
class CommonConstants {
    
    # Determines whether the scripts are running as a Runbook or locally.
    static [string] $ExecutionEnvironment = 'Runbook' # Possible values : Runbook, Local
    static [boolean] $IsExecutingAsRunbook = ([CommonConstants]::$ExecutionEnvironment -eq 'Runbook')

    static [Hashtable] $ResourceTypeToTemplateFolderMap = @{
        "Virtual Network" = @{ TemplateFolderName = 'vnet' };
    }
}
