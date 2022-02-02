#Requires -Version 5.1
if ($PSVersionTable.PSVersion.Major -eq 6) {
    $env:PSExecutionPolicyPreference = $null
    throw 'PowerProfile requires PowerShell Core version 7.0 or higher'
}

#region Preparation
$PoProfileOriginScriptPath = (Get-PSCallStack)[1].InvocationInfo.MyCommand.Path      # [...]\Documents\PowerShell\profile.ps1
if ($null -ne $PoProfileOriginScriptPath) {
    $PoProfileModulePath = [System.IO.Path]::Combine(                                # [...]\Documents\PowerShell\Modules
                    (Split-Path $PoProfileOriginScriptPath),
                    'Modules'
                )
}
elseif ($PSEdition -eq 'Desktop' -or $IsWindows) {
    $env:PSExecutionPolicyPreference = 'RemoteSigned'
    Get-ChildItem -File -Recurse -FollowSymlink -Path $PSScriptRoot | ForEach-Object { Unblock-File -Path $_.FullName -ErrorAction Ignore -Confirm:$false -WhatIf:$false }
}

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

Import-Module -Force -DisableNameChecking -Name ([System.IO.Path]::Combine($PSScriptRoot,'PowerProfile.Core.psd1')) -ErrorAction Stop
#endregion

#region Setup
if ($null -eq $PoProfileOriginScriptPath) {
    Write-PoProfileProgress -ProfileTitle "`nPowerProfile Initialization"

    $PoProfileModulePath = Join-Path (Split-Path $PROFILE.CurrentUserAllHosts) 'Modules'
    $datetime = (Get-Date).ToString('yyyy-MM-dd_HHmmss')

    if ($PSScriptRoot -notmatch "^$([regex]::Escape($PoProfileModulePath))") {
        $null = New-Item -ItemType Directory -Force -Path $PoProfileModulePath -ErrorAction Ignore
        Write-PoProfileProgress -ScriptTitleType Error -ScriptTitle @(
            'ERROR:'
            ('Move the '+'`'+"$($PSStyle.Italic)PowerProfile$($PSStyle.ItalicOff)"+'`'+' folder '+" from $($PSStyle.FormatHyperlink('here','file://'+(Split-Path $PSScriptRoot))) to profile folder $($PSStyle.FormatHyperlink($PoProfileModulePath,'file://'+$PoProfileModulePath)) first.")
        )
        Remove-Module -Force PowerProfile.Core -ErrorAction Ignore
        $env:PSExecutionPolicyPreference = $null
        throw
    }

    if (Test-Path $PROFILE.CurrentUserCurrentHost) {
        $bak = $PROFILE.CurrentUserCurrentHost + '.bak.' + $datetime
        Rename-Item $PROFILE.CurrentUserCurrentHost $bak
        Write-PoProfileProgress -ScriptTitleType Information -ScriptTitle @(
            ($PSStyle.Italic + (Split-Path -Leaf $PROFILE.CurrentUserCurrentHost) + $PSStyle.ItalicOff + ' backed up:')
            "The existing file was renamed to $($PSStyle.FormatHyperlink((Split-Path -Leaf $bak),'file://'+(Split-Path $bak)))"
            'for further investigation.'
        )
    }

    if (Test-Path $PROFILE.CurrentUserAllHosts) {
        if (
            (Get-FileHash -Path (Join-Path $PSScriptRoot 'profile.ps1')).Hash -ne
            (Get-FileHash -Path $PROFILE.CurrentUserAllHosts).Hash
        ) {
            $bak = $PROFILE.CurrentUserAllHosts + '.bak.' + $datetime
            Rename-Item $PROFILE.CurrentUserAllHosts $bak

            Write-PoProfileProgress -ScriptTitleType Information -ScriptTitle @(
                ($PSStyle.Italic + (Split-Path -Leaf $PROFILE.CurrentUserAllHosts) + $PSStyle.ItalicOff + ' backed up:')
                "The existing file was renamed to $($PSStyle.FormatHyperlink((Split-Path -Leaf $bak),'file://'+(Split-Path $bak)))"
                'for further investigation.'
            )

            Copy-Item (Join-Path $PSScriptRoot 'profile.ps1') $PROFILE.CurrentUserAllHosts
            $SetupCompleted = $true
        }
    } else {
        Copy-Item (Join-Path $PSScriptRoot 'profile.ps1') $PROFILE.CurrentUserAllHosts
        $SetupCompleted = $true
    }

    if ($SetupCompleted) {
        Remove-Variable -Name 'SetupCompleted'

        Write-PoProfileProgress -ScriptTitleType Confirmation -ScriptTitle 'PowerProfile Setup COMPLETED !'
        Write-PoProfileProgress -ScriptTitleType Note -NoCounter -ScriptTitle ('Use the '+'`'+"$($PSStyle.Italic)New-PowerProfile$($PSStyle.ItalicOff)"+'`'+' command to create profile directories.')
        Write-PoProfileProgress -ScriptTitleType Note -NoCounter -ScriptTitle ('Type '+'`'+"$($PSStyle.Italic)help PowerProfile$($PSStyle.ItalicOff)"+'`'+' for more details,')
        Write-PoProfileProgress -ScriptTitleType Note -NoCounter -ScriptTitle ("or visit $($PSStyle.FormatHyperlink('the PowerProfile website','https://PowerProfile.sh/')) to learn more about PowerProfile.")
    }
}
#endregion

#region Preloading checks
elseif ($PSScriptRoot -notmatch "^$([regex]::Escape($PoProfileModulePath))") {
    Write-PoProfileProgress -ProfileTitle "PowerProfile Error" -ScriptTitleType Error -ScriptTitle @(
        'The PowerProfile module is not saved as part of your profile.'
        "Make sure the module files are moved back into $($PSStyle.FormatHyperlink('this Modules folder','file://'+$PoProfileModulePath))."
    )
    Remove-Module -Force PowerProfile.Core -ErrorAction Ignore
    $env:PSExecutionPolicyPreference = $null
    throw
}
elseif ($PoProfileOriginScriptPath -ne $PROFILE.CurrentUserAllHosts) {
    Remove-Module -Force PowerProfile.Core -ErrorAction Ignore
    $env:PSExecutionPolicyPreference = $null
    throw 'PowerProfile can not be imported into other PowerShell scripts or modules'
}
#endregion

Remove-Variable -Name 'PoProfileOriginScriptPath','PoProfileModulePath'
