if (
    (
        $CurrentProfile -eq 'Profile' -and
        $SetupState.'0001.PoProfile-Validate PowerShell Package Management.Setup.ps1'.State -ne 'Complete'
    ) -or
    (
        $CurrentProfile -ne 'Profile' -and
        (Get-PoProfileState 'PoProfile.Setup.Profile').'0001.PoProfile-Validate PowerShell Package Management.Setup.ps1'.State -ne 'Complete'
    )
) {
    $SetupState.$ScriptFullName.State = 'PendingPackageManagementSetup'
    Continue ScriptNames
}

$Files = (Get-PoProfileContent).ConfigDirs.$CurrentProfile.'Install-Module'

if ($null -eq $Files) {
    $SetupState.$ScriptFullName.State = 'Complete'
    Continue ScriptNames
}

Remove-Module PowerShellGet -Force -ErrorAction Ignore
Remove-Module PackageManagement -Force -ErrorAction Ignore
Remove-Module CompatPowerShellGet -Force -ErrorAction Ignore
Import-Module -Name PowerShellGet -MaximumVersion 2.*

foreach ($File in $Files.GetEnumerator()) {
    if ($File.Name -match '\.PSModule\.(json|psd1)$') {
        if ($Matches[1] -eq 'json') {
            if ($IsCoreCLR) {
                $FData = ConvertFrom-Json -InputObject ([System.IO.File]::ReadAllText($File.Value)) -AsHashtable
            } else {
                $FData = ConvertFrom-Json -InputObject ([System.IO.File]::ReadAllText($File.Value))
            }
        } else {
            $FData = Import-PowerShellDataFile -Path $File.Value
        }
    } else {
        continue
    }

    foreach ($Module in $FData.GetEnumerator()) {
        if ($Module.Value -is [string]) {
            if ($Module.Value -eq '*') {
                $Params = @{}
            } elseif ($Module.Value -eq '*-*') {
                $Params = @{
                    AllowPrerelease = $true
                }
            } else {
                $Params = @{
                    MinimumVersion = $Module.Value
                }
            }
        } else {
            $Params = $Module.Value
        }

        if (
            $Params.Scope -eq 'AllUsers' -and
            $IsWindows -and
            $null -eq $env:IsElevated
        ) {
            $SetupState.$ScriptFullName.State = 'PendingElevation'
            continue
        }

        if (
            $null -eq $Params.AllowPrerelease -and
            (
                $Params.MinimumVersion -match '-' -or
                $Params.MaximumVersion -match '-' -or
                $Params.RequiredVersion -match '-' -or
                (
                    $Module.Name -eq 'PowerProfile.Commands' -and
                    $PoProfilePrerelease
                )
            )
        ) {
            $Params.AllowPrerelease = $true
        }

        # take over default behaviour from PowerShellGetV3
        if ($null -eq $Params.AllowClobber) {
            $Params.AllowClobber = $true
        }

        # Prioritize PSGallery / lazy substitute for priority
        #  setting from PowerShellGetV3
        if ($null -eq $Params.Repository) {
            $Params.Repository = 'PSGallery'
        }

        try {
            Write-Host "      $($Module.Name)"
            Install-Module @Params -Name $Module.Name -WarningAction Ignore -ErrorAction Stop -Confirm:$false -WhatIf:$false
        }
        catch {
            $SetupState.$ScriptFullName.ErrorMessage += "$($Module.Name): $_"
            $SetupState.$ScriptFullName.State = 'Error'
        }
    }
}

Remove-Module PowerShellGet -Force -ErrorAction Ignore
Remove-Module PackageManagement -Force -ErrorAction Ignore

if ($SetupState.$ScriptFullName.State -ne 'Error') {
    $SetupState.$ScriptFullName.State = 'Complete'
}
