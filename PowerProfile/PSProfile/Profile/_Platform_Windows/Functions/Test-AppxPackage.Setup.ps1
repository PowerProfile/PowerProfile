function Test-AppxPackage {
<#
.SYNOPSIS
    Test if AppxPackage is installed

.DESCRIPTION
    Test if AppxPackage is installed

.PARAMETER GetAttributeName
    Returns the value of the desired attribute from the installed AppxPackage

.LINK
    https://github.com/PowerProfile/psprofile-common
#>

    Param (
        [Parameter(Mandatory = $true)] [string] $Name,
        [Parameter(Mandatory = $false)] [string] $GetAttributeName
    )

    if ($PSEdition -eq 'Core') {
        Import-Module Appx -UseWindowsPowerShell 3>$null
    }

    $appDetails = Get-AppxPackage | Where-Object Name -EQ $Name

    if ($PSEdition -eq 'Core') {
        Remove-Module Appx
    }

    if ($appDetails) {
        if ($GetAttributeName -and $appDetails.$GetAttributeName) {
            return $appDetails.$GetAttributeName
        }
        return $true
    }
    return $false
}
