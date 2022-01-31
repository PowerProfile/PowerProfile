$Settings = (Get-PoProfileContent).ConfigDirs.$CurrentProfile.'Settings'

if ($null -eq $Settings) {
    continue ScriptNames
}

foreach ($File in $Settings.GetEnumerator()) {
    if ($File.Name -match '\.Settings\.(json|psd1)$') {
        if ($Matches[1] -eq 'json') {
            $Cfg = ConvertFrom-Json -InputObject ([System.IO.File]::ReadAllText($File.Value)) -AsHashtable
        } else {
            $Cfg = Import-PowerShellDataFile -Path $File.Value
        }
    } else {
        continue
    }

    if ($null -ne $Cfg.ModuleName) {
        if (-Not (Get-Module -ListAvailable -Name $Cfg.ModuleName)) {
            continue
        }

        if (
            (
                $null -ne $Cfg.MinimumVersion -and
                ((Get-Module -ListAvailable -Name $Cfg.ModuleName).Version -lt [version]$Cfg.MinimumVersion)
            ) -or
            (
                $null -ne $Cfg.MaximumVersion -and
                ((Get-Module -ListAvailable -Name $Cfg.ModuleName).Version -gt [version]$Cfg.MaximumVersion)
            ) -or
            (
                $null -ne $Cfg.RequiredVersion -and
                ((Get-Module -ListAvailable -Name $Cfg.ModuleName).Version -ne [version]$Cfg.RequiredVersion)
            )
        ) {
            Continue
        }
    }

    if ($null -ne $Cfg.ApplicationName) {
        if (-Not (Get-Command -CommandType Application -Name $Cfg.ApplicationName)) {
            continue
        }
    }

    if ($null -ne $Cfg.EnvironmentVariables) {
        foreach ($EnvVar in $Cfg.EnvironmentVariables.GetEnumerator()) {
            try {
                [System.Environment]::SetEnvironmentVariable($EnvVar.Name,$EnvVar.Value)
            }
            catch {

            }
        }
    }

    if ($null -ne $Cfg.Commands) {
        foreach ($Command in $Cfg.Commands.GetEnumerator()) {
            if ($Command.Value -is [array]) {
                foreach ($Params in $Command.Value) {

                    # repeat the same PowerShell command using different parameters
                    if ($Params -is [Hashtable]) {
                        try {
                            Invoke-Expression "$($Command.Name) @Params"
                        }
                        catch {

                        }
                    }

                    # One or many commands without parameter hash
                    else {
                        try {
                            Invoke-Expression "$($Params)"
                        }
                        catch {

                        }
                    }
                }
            } elseif ($Command.Value -is [Hashtable]) {
                $Params = $Command.Value
                try {
                    Invoke-Expression "$($Command.Name) @Params"
                }
                catch {

                }
            }
        }
    }
}
