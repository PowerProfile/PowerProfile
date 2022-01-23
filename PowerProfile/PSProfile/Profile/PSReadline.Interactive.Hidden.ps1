$CfgPath = (Get-PoProfileContent).Config.$CurrentProfile.'PSReadline.config.psd1'
if ($CfgPath) {
    $Cfg = Import-PowerShellDataFile -Path $CfgPath

    if (
        $null -ne $Cfg.ModuleName -and
        $null -ne $Cfg.MinimumVersion -and
        ((Get-Module $Cfg.ModuleName).Version -lt [version]$Cfg.MinimumVersion)
    ) {
        Continue ScriptNames
    }

    foreach ($Command in $Cfg.Commands.GetEnumerator()) {
        if ($Command.Value -is [array]) {
            foreach ($Params in $Command.Value) {
                Invoke-Expression "$($Command.Name) @Params"
            }
        } elseif ($Command.Value -is [Hashtable]) {
            $Params = $Command.Value
            Invoke-Expression "$($Command.Name) @Params"
        }
    }
}
