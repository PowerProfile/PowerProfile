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
    $SetupState.$ScriptFullName.State = 'PendingPowerShellGetUpgrade'
    continue ScriptNames
}

$Settings = (Get-PoProfileContent).ConfigDirs.$CurrentProfile.'WinGet'

if ($null -eq $Settings -or $Settings.Count -eq 0) {
    $SetupState.$ScriptFullName.State = 'Complete'
    continue ScriptNames
}

if (-Not (Get-Command winget -CommandType Application -ErrorAction Ignore)) {
    Start-Job -Name WingetInstall -ScriptBlock { Add-AppxPackage -Path https://aka.ms/getwinget -ErrorAction Ignore }
    Wait-Job -Name WingetInstall

    if (-Not (Get-Command winget -CommandType Application -ErrorAction Ignore)) {
        $SetupState.$ScriptFullName.State = 'FailedWinGetSetup'
        continue ScriptNames
    }
}

[System.Collections.ArrayList]$Wingetfiles = $Settings.keys

if ($Wingetfiles.Count -gt 1) {
    if ($Wingetfiles -contains 'PoProfile.WinGet.psd1') {
        $Wingetfiles.Remove('PoProfile.WinGet.psd1')
        $Wingetfiles.Insert(0,'PoProfile.WinGet.psd1')
    }
    if ($Wingetfiles -contains 'PoProfile.WinGet.json') {
        $Wingetfiles.Remove('PoProfile.WinGet.json')
        $Wingetfiles.Insert(0,'PoProfile.WinGet.json')
    }
}

$ExitCodeSum = 0
[version]$version = (winget --version).Substring(1)

foreach ($Wingetfile in $Wingetfiles) {
    if ($Wingetfile -match '\.WinGet\.json$') {
        try {
            $Cfg = ConvertFrom-Json -InputObject ([System.IO.File]::ReadAllText($Settings.$Wingetfile))
        }
        catch {
            continue
        }
    } else {
        continue
    }

    if ($null -ne $Cfg.WinGetVersion -and $version -lt [version]$Cfg.WinGetVersion) {
        continue
    }

    # We can't use the WinGet import command as it will not detect apps that are already installed.
    #  Also, JSON standard format will not support every command line flag, e.g. Scope.
    foreach ($Source in $Cfg.Sources) {
        if ($null -eq $Source.SourceDetails.Name) {
            continue
        }

        $ListSource = winget source list --name $Source.SourceDetails.Name

        if ($LASTEXITCODE -ne 0) {
            if ($null -ne $env:CanElevate -or $null -ne $env:IsElevated) {
                if (
                    $Source.SourceDetails.Name -eq 'msstore' -or
                    $Source.SourceDetails.Name -eq 'winget'
                ) {
                    $cmd = Start-Process -Verb RunAs -WindowStyle Hidden -PassThru -Wait -FilePath winget -ArgumentList @(
                        'source'
                        'reset'
                        '--force'
                    )
                    if ($cmd.ExitCode -ne 0) {
                        $ExitCodeSum += $cmd.ExitCode
                        continue
                    }
                }
                elseif ($null -ne $Source.SourceDetails.Argument) {
                    $cmd = Start-Process -Verb RunAs -WindowStyle Hidden -PassThru -Wait -FilePath winget -ArgumentList @(
                        'source'
                        'add'
                        '--accept-source-agreements'
                        "--arg $($Source.SourceDetails.Argument)"
                        $(
                            if ($null -ne $Source.SourceDetails.Type) {
                                "--type $($Source.SourceDetails.Type)"
                            }
                        )
                    )
                    if ($cmd.ExitCode -ne 0) {
                        $ExitCodeSum += $cmd.ExitCode
                        continue
                    }
                } else {
                    $ExitCodeSum += $LASTEXITCODE
                    continue
                }
            } else {
                $ExitCodeSum += $LASTEXITCODE
                continue
            }
        }

        foreach ($Package in $Source.Packages) {
            $Params = @{
                source = $Source.SourceDetails.Name
            }
            foreach ($Property in $Package.PSObject.Properties) {
                if ($Property.Name -eq 'PackageIdentifier') {
                    $Params.id = $Property.Value
                } else {
                    $Params.$($Property.Name.ToLower()) = $Property.Value
                }
            }
            if ($null -eq $Params.id) {
                continue
            }

            if ($Params.name) {
                $AppName = $Params.name
                $ListApps = (winget list --name `"$AppName`" --exact).Split("`n")
                $Params.Remove('Name')
                $Params.exact = $true
            } else {
                $AppName = $Params.id
                $ListApps = (winget list --source $Params.source --id $AppName --exact).Split("`n")
            }
            Write-Host ('      ' + $AppName)
            if ($ListApps.Count -ge 4) {
                continue
            }
            $cmd = 'winget install'
            foreach ($Param in $Params.GetEnumerator()) {
                if ($Param.Name.Length -eq 1) {
                    $cmd += ' -' + $Param.Name
                } else {
                    $cmd += ' --' + $Param.Name
                }
                if ($Param.Value -isnot [Boolean]) {
                    $cmd += ' ' + $Param.Value
                }
            }
            Invoke-Expression $cmd
            if ($LASTEXITCODE -ne 0) {
                $ExitCodeSum += $LASTEXITCODE
            }
        }
    }
}

if ($ExitCodeSum -eq 0) {
    $SetupState.$ScriptFullName.State = 'Complete'
}
