$Settings = (Get-PoProfileContent).ConfigDirs.$CurrentProfile.'Settings'

if ($null -eq $Settings -or $Settings.Count -eq 0) {
    continue ScriptNames
}

$Exports = @{
    Alias = @()
    Variable = @()
}

foreach ($File in $Settings.GetEnumerator()) {
    if ($File.Name -match '\.Settings\.(json|psd1)$') {
        try {
            if ($Matches[1] -eq 'json') {
                if ($IsCoreCLR) {
                    $Cfg = ConvertFrom-Json -InputObject ([System.IO.File]::ReadAllText($File.Value)) -AsHashtable
                } else {
                    $Cfg = ConvertFrom-Json -InputObject ([System.IO.File]::ReadAllText($File.Value))
                }
            } else {
                $Cfg = Import-PowerShellDataFile -Path $File.Value
            }
        }
        catch {
            continue
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
            continue
        }
    }

    if ($null -ne $Cfg.ApplicationName) {
        if (-Not (Get-Command -CommandType Application -Name $Cfg.ApplicationName)) {
            continue
        }
    }

    if ($null -ne $Cfg.Variables) {
        foreach ($Var in $Cfg.Variables.GetEnumerator()) {
            if ($Var.Value -is [string]) {
                $Params = @{
                    Scope = 'Script'
                    Name = $Var.Name
                    Value = $Var.Value
                    Description = 'Configuration set by ' + $File.Value
                }
                Set-Variable @Params
                $Exports.Variable += $Var.Name
            } elseif ($Var.Value -is [Hashtable]) {
                $Params = $Var.Value
                $Params.Scope = 'Script'
                $Params.Name = $Var.Name
                if ($null -eq $Params.Description) {
                    $Params.Description = 'Configuration set by ' + $File.Value
                }
                if ($null -ne $Params.Value) {
                    Set-Variable @Params
                    $Exports.Variable += $Params.Name
                }
            }
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

    if ($null -ne $Cfg.Aliases) {
        foreach ($Alias in $Cfg.Aliases.GetEnumerator()) {
            if ($Alias.Value -is [string]) {
                $Params = @{
                    Scope = 'Script'
                    Name = $Alias.Name
                    Value = $Alias.Value
                    Description = 'Alias set by ' + $File.Value
                }
                Set-Alias @Params
                $Exports.Alias += $Alias.Name
            } elseif ($Alias.Value -is [Hashtable]) {
                $Params = $Alias.Value
                $Params.Scope = 'Script'
                $Params.Name = $Alias.Name
                if ($null -eq $Params.Description) {
                    $Params.Description = 'Alias set by ' + $File.Value
                }
                if ($null -ne $Params.Value) {
                    Set-Alias @Params
                    $Exports.Alias += $Params.Name
                }
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

Export-ModuleMember @Exports
