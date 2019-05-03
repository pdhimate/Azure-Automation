<#
	Has common methods for output, copy & validations, which are used in all other modules and scripts. 
#>

<#
    Display error message in the Output as well as Error Streams. 
    This is useful for logging.
#>
function Write-ErrorOutput {
    param (
        [string]$errorMessage
    )
    $errorString = "Error : " + $errorMessage

    # Display the error in the Output stream
    Write-Output $errorString

    # Display the error in the Error Stream as well. 
    Write-Error -Message $errorString  # this also fails the script since $ErrorPreference is set to STOP
}

<# 
    Copies the Properties of the Input object to the Output object, thus creating a deep copy.
#>
function Copy-HashTable {
    param (
        [HashTable] $InputHashTable,
        [HashTable] $OutputHashTable
    )
    # Note: Do not assign New instances to the Output object since this is only intended to copy the Properties
    #       and doing so will stop functions with -Output object from working. 
    if ($InputHashTable -and $OutputHashTable) {
        ($InputHashTable | ConvertTo-Json -depth 100 | ConvertFrom-Json).PSObject.Properties | ForEach-Object {
            $OutputHashTable[$_.Name] = $_.Value 
        }     
    }
}

<#
    Removes any leading or trailing white spaces from the input string.
#>
function Clear-WhiteSpace {
    param (
        [string] $InputString
    )
    if ($InputString) {
        $InputString = $InputString.Trim()
    }

    return $InputString
}

# Reduces the length of the specified string, if it exceeds the permitted limit.
function Get-TrimmedString {
    param (
        [string] $InputString,
        [int] $MaxLength
    )
    $name = $InputString

    if ($InputString.Length -gt $MaxLength ) {
        $name = $InputString.Substring(0, $MaxLength)
    }

    return $name
}

# Extacts a JSON object from JSON string specified between start and end indicator string from a text.
function Search-JsonObjectInText {
    param (
        [string] $Text, # the text that contains JSON string between the Start and End indicator strings
        [string] $StartIndicator, # the string that indicates the start of the target JSON 
        [string] $EndIndicator, # the string that indicates the end of the target JSON
        [HashTable] $Output 
    )
    Write-Output "Parsing text to extract JSON between $StartIndicator and $EndIndicator"

    # Validate
    $startIndicatorIndex = $text.IndexOf($StartIndicator)
    if ($startIndicatorIndex -lt 0) {
        Write-ErrorOutput "Could not find $StartIndicator in the input text"
    }        
    $endIndicatorIndex = $text.IndexOf($EndIndicator)
    if ($endIndicatorIndex -lt 0) {
        Write-ErrorOutput "Could not find $EndIndicator in the input text"
    }        

    # Parse
    $startIndex = $startIndicatorIndex + $StartIndicator.Length
    $endIndex = $endIndicatorIndex
    $length = $endIndex - $startIndex
    if ($length -lt 1) {
        Write-Error "Could not find string between the start : $StartIndicator and end : $EndIndicator "
    }
    Write-Output "Start index: $startIndex, End Index: $endIndex, Length : $length"
    $jsonOutputString = $text.SubString($startIndex, $length)
    Write-Output "Parsing complete. Json output object is: "
    $jsonObj = $jsonOutputString | ConvertFrom-Json

    # Set outputs
    $Output.JsonObj = $jsonObj
}

# Generates a lowercase alphabetic pseudorandom id of the specified length
function Get-PseudoRandomId {
    param (
        [int] $size 
    )
    $set = "abcdefghijklmnopqrstuvwxyz".ToCharArray()
    $result = ""
    for ($x = 0; $x -lt $size; $x++) {
        $result += $set | Get-Random
    }
    return  $result
}

<#
    Recursively converts the specified Hastable  of string,object to HashTable of string,HashTables.
#>
Function ConvertTo-NestedHashTables {
    param (
        [Hashtable] $TargetHashTable
    )

    # Validate
    if ($null -eq $TargetHashTable) {
        Write-Output "Target Hash Table was null"
        return $null
    }

    $nestedHashTables = New-Object -TypeName Hashtable
    foreach ($kvp1 in $TargetHashTable.GetEnumerator()) {
        # If KVP.value is not null and is possibly a HashTable, call recursively
        $val = $kvp1.Value
        if (($val) -and ($val).GetType().Name -eq "HashTable") {
            $rcCurrResource = New-Object -TypeName Hashtable
            $rcCurrResource = ConvertTo-NestedHashTables -TargetHashTable $val
            $nestedHashTables[$kvp1.Name] = [Hashtable]$rcCurrResource
        }
        # If KVP.value is not HashTable, just assign the value as it is.
        else {
            $nestedHashTables[$kvp1.Name] = $kvp1.Value
        }
    }

    return $nestedHashTables
}
