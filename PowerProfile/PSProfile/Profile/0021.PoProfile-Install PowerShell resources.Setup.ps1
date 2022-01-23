$Files = (Get-PoProfileContent).ConfigDirs.$CurrentProfile.'Install-PSResource'

if ($null -eq $Files) {
    $SetupState.$ScriptFullName.State = 'Complete'
    Continue ScriptNames
}

Remove-Module PowerShellGet -Force -ErrorAction Ignore
Remove-Module PackageManagement -Force -ErrorAction Ignore
Import-Module -Name PowerShellGet -MinimumVersion 3.0

foreach ($File in $Files.GetEnumerator()) {
    if ($File.Name -match '\.PSResource\.(json|psd1)$') {
        if ($Matches[1] -eq 'json') {
            $FData = ConvertFrom-Json -InputObject ([System.IO.File]::ReadAllText($File.Value)) -AsHashtable
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
            $null -eq $Params.Prerelease -and
            $Params.Version -match '-'
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
