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

    if ($null -eq $Cfg.Commands) {
        continue
    }

    elseif (
        $null -ne $Cfg.ModuleName -and
        (
            (
                $null -ne $Cfg.MinimumVersion -and
                ((Get-Module $Cfg.ModuleName).Version -lt [version]$Cfg.MinimumVersion)
            ) -or
            (
                $null -ne $Cfg.MaximumVersion -and
                ((Get-Module $Cfg.ModuleName).Version -gt [version]$Cfg.MaximumVersion)
            ) -or
            (
                $null -ne $Cfg.RequiredVersion -and
                ((Get-Module $Cfg.ModuleName).Version -ne [version]$Cfg.RequiredVersion)
            )
        )
    ) {
        Continue
    }

    foreach ($Command in $Cfg.Commands.GetEnumerator()) {
        if ($Command.Value -is [array]) {
            foreach ($Params in $Command.Value) {
                try {
                    Invoke-Expression "$($Command.Name) @Params"
                }
                catch {

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
