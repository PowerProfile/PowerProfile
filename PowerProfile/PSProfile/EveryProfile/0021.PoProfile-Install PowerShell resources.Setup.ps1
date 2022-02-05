if (
    (
        $CurrentProfile -eq 'Profile' -and
        $SetupState.'0001.PoProfile-Validate PowerShellGet.Setup.ps1'.State -ne 'Complete'
    ) -or
    (
        $CurrentProfile -ne 'Profile' -and
        (Get-PoProfileState 'PoProfile.Setup.Profile').'0001.PoProfile-Validate PowerShellGet.Setup.ps1'.State -ne 'Complete'
    )
) {
    $SetupState.$ScriptFullName.State = 'PendingPackageManagementSetup'
    Continue ScriptNames
}


$Files = (Get-PoProfileContent).ConfigDirs.$CurrentProfile.'Install-PSResource'

if ($null -eq $Files -or $Files.Count -eq 0) {
    $SetupState.$ScriptFullName.State = 'Complete'
    Continue ScriptNames
}

Remove-Module PowerShellGet -Force -ErrorAction Ignore
Remove-Module PackageManagement -Force -ErrorAction Ignore
Import-Module -Name PowerShellGet -MinimumVersion 3.0

foreach ($File in $Files.GetEnumerator()) {
    if ($File.Name -match '\.PSResource\.(json|psd1)$') {
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
            $Params = @{
                Version = $Module.Value
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
            $null -eq $Params.Prerelease -and
            (
                $Params.Version -match '-' -or
                (
                    $Module.Name -eq 'PowerProfile.Commands' -and
                    $PoProfilePrerelease
                )
            )
        ) {
            $Params.Prerelease = $true
        }

        try {
            Write-Host "      $($Module.Name)"
            Install-PSResource @Params -Name $Module.Name -WarningAction Ignore -ErrorAction Stop
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
