#Requires -Version 5.1
#Requires -Modules 'PowerProfile.Core'

$ExecutionContext.SessionState.Module.OnRemove = {
    function Global:prompt {
        "PS $($executionContext.SessionState.Path.CurrentLocation)$('>' * ($nestedPromptLevel + 1)) ";
    }
    Remove-Module -Force -Name PowerProfile-Dyn.* -ErrorAction Ignore
    Remove-Module -Force -Name PowerProfile.Core.Load -ErrorAction Ignore
    Remove-Module -Force -Name PowerProfile.Core -ErrorAction Ignore
}

#region PowerProfile Environment
if ($null -eq $env:PSLVL) {
    if ((Get-PoProfileContent).Modules.Count -gt 0) {
        [array]::Reverse((Get-PoProfileContent).Modules)
        foreach ($p in (Get-PoProfileContent).Modules) {
            $env:PSModulePath += [System.IO.Path]::PathSeparator + $p
        }
    }
    if ((Get-PoProfileContent).Scripts.Count -gt 0) {
        [array]::Reverse((Get-PoProfileContent).Scripts)
        foreach ($p in (Get-PoProfileContent).Scripts) {
            $env:PATH += [System.IO.Path]::PathSeparator + $p
        }
    }
}
#endregion

#region Profiles
function Initialize-Profiles {
    Write-PoProfileProgress -ProfileTitle 'Loading profile'

    #region User functions
    if ((Get-PoProfileContent).Functions.Count -gt 0) {
        New-Module -Name 'PowerProfile-Dyn.Functions' -ScriptBlock {
            $ErrorActionPreference = 'Stop'

            foreach ($key in (Get-PoProfileContent).Functions.Keys) {
                try {
                    $null = . (Get-PoProfileContent).Functions.$key
                }
                catch {
                    Write-PoProfileItemProgress -ItemTitle 'Failed to import functions' -ItemTextColor $PSStyle.Foreground.BrightRed -Depth 1 -ItemText (((Split-Path -Leaf $key) -replace '^[0-9][\w.]*-','') -replace '\.[^.]*$','')
                }
            }
            Export-ModuleMember -Function * -Alias * -Variable @()
        } | Import-Module -Global -DisableNameChecking
    }
    #endregion

    #region User profiles
    $ProfileId = 1
    foreach ($Global:PoProfileTmpThisProfile in @(Get-PoProfileProfilesList)) {
        if ($null -eq (Get-PoProfileContent).Profiles.$($PoProfileTmpThisProfile)) {
            continue
        }

        switch ($ProfileId) {
            1 {
                $DynModName = 'PowerProfile-Dyn.Scripts'
            }
            2 {
                $DynModName = 'PowerProfile-Dyn.Scripts.' + (($env:LC_PSHOST -replace ' ','.') -replace '_','')
                Write-PoProfileProgress -ProfileTitle "Loading profile for $env:LC_PSHOST"
                if ([System.IO.File]::Exists($PROFILE.CurrentUserCurrentHost)) {
                    Write-PoProfileProgress -ScriptTitleType Warning -ScriptTitle ((Split-Path -Leaf $PROFILE.CurrentUserCurrentHost)+' might interfere with PowerProfile.'),'You should delete the file and transform its functionality to PowerProfile directory format.'
                }
            }
            3 {
                $DynModName = 'PowerProfile-Dyn.Scripts.' + (($env:LC_TERMINAL -replace ' ','.') -replace '_','')
                Write-PoProfileProgress -ProfileTitle "Loading profile for $env:LC_TERMINAL"
            }
        }

        New-Module -Name $DynModName -ScriptBlock {
            $ErrorActionPreference = 'Stop'

            foreach ($key in (Get-PoProfileContent).Profiles.$($PoProfileTmpThisProfile).keys) {

                $hidden = $false
                $output = $false
                $run = $true
                $setup = $false

                if ($key -match '^([0-9]{4,})?((?:\.\w+)+)?-?([\w ]+)((?:\.\w+)+)?\.(\w+)$') {
                    if ($null -ne $Matches[1]) {
                        [decimal]$ScriptSortingNumber = $Matches[1]
                    }
                    if ($null -ne $Matches[2]) {
                        $ScriptProviderDetails = $Matches[2].Substring(1).Split('.')
                    }
                    $PoProfileSciptName = $Matches[3] -replace '_',' '
                    if ($null -ne $Matches[4]) {

                        switch ($Matches[4].Substring(1).Split('.')) {

                            Hidden {
                                $hidden = $true
                            }

                            Output {
                                $output = $true
                            }

                            Setup {
                                if (
                                    $IsNonInteractive -or
                                    $IsCommand -or
                                    $null -ne $env:PSLVL
                                ) {
                                    $run = $false
                                    break
                                }
                                $setup = $true
                            }

                            Interactive {
                                if (
                                    $IsNonInteractive -or
                                    $null -ne $env:PSLVL -or
                                    (
                                        $IsCommand -and
                                        $null -eq $IsNoExit
                                        )
                                ) {
                                    $run = $false
                                    break
                                }
                            }

                            NonInteractive {
                                if (
                                    -Not $IsNonInteractive -or
                                    $null -ne $env:PSLVL
                                ) {
                                    $run = $false
                                    break
                                }
                            }

                            Command {
                                if (-Not $IsCommand) {
                                    $run = $false
                                    break
                                }
                            }

                            NoCommand {
                                if ($IsCommand) {
                                    $run = $false
                                    break
                                }
                            }

                            CommandNoExit {
                                if (
                                    -Not $IsCommand -or
                                    -Not $IsNoExit
                                ) {
                                    $run = $false
                                    break
                                }
                            }

                            Login {
                                if (-Not $IsLogin) {
                                    $run = $false
                                }
                            }

                            NoLogin {
                                if ($IsLogin) {
                                    $run = $false
                                }
                            }

                            Elevated {
                                if ($null -eq $env:IsElevated) {
                                    $run = $false
                                }
                            }

                            NotElevated {
                                if ($null -ne $env:IsElevated) {
                                    $run = $false
                                }
                            }

                            Default {
                                Write-Error "${key}: Unknown script name property $_"
                            }

                        }
                    }
                } else {
                    Write-PoProfileProgress -ScriptTitle ($PSStyle.Foreground.BrightYellow + $PSStyle.BoldOff + '[Ignored] ' + $PSStyle.Foreground.White + $key + $PSStyle.Foreground.Yellow + ' (file name order number?)') -NoCounter
                    continue
                }

                if (-Not $run) {
                    if (-Not $hidden) {
                        Write-PoProfileProgress -ScriptTitle ($PSStyle.Foreground.Yellow + $PSStyle.BoldOff + '[Skipped] ' + $PSStyle.Foreground.White + $PoProfileSciptName) -NoCounter
                    }
                    Continue
                }

                if (-Not $hidden) {
                    Write-PoProfileProgress -ScriptTitle $PoProfileSciptName
                }

                try {
                    if ($output) {
                        Write-Host "$key with output,  setup: $setup"
                        . (Get-PoProfileContent).Profiles.$($PoProfileTmpThisProfile).$key
                    } else {
                        Write-Host "$key w/o output,  setup: $setup"
                        $null = . (Get-PoProfileContent).Profiles.$($PoProfileTmpThisProfile).$key
                    }
                }
                catch {
                    if (-Not $output) {
                        Write-Host "$key ERROR"
                        if ($hidden) {
                            Write-PoProfileProgress -ScriptTitle $PoProfileSciptName
                        }
                        Write-PoProfileProgress -ScriptTitle @(($_.Exception.Message).Trim() -split [System.Environment]::NewLine) -ScriptTitleType Error
                    }
                }
            }
        } | Import-Module -Global -DisableNameChecking

        $ProfileId++
    }
    #endregion
}

# Load narrow profile
if ($IsCommand) {
    Initialize-Profiles
}

# Load full interactive profile
if(-Not $IsCommand -or $IsNoExit) {

    # Environment notices
    if ($null -eq $env:PSLVL -and -Not $IsNoExit) {
        Write-PoProfileProgress -ProfileTitle 'NOTICE' -ScriptCategory ''
        if ($null -ne $env:IsElevated) {
            Write-PoProfileProgress -ScriptTitle 'Careful! Running session with ELEVATED PRIVILEGES' -ScriptTitleType Warning
        }
        if ($IsWindows -and $null -ne $env:IsProfileRedirected) {
            Start-Job -Name 'PROFILEHOMEAttr' -ScriptBlock { attrib.exe +P $PROFILEHOME; Push-Location $PROFILEHOME; attrib.exe +P /S /D /L }
        }
    }

    # Load scripts from narrow profile if not loaded already
    if (-Not $IsCommand) {
        Initialize-Profiles
    }

    Write-PoProfileProgress -ProfileTitle 'INITIALIZATION COMPLETED' # just to get newline in case we had output before
    Remove-Variable PoProfileTmp* -Scope Global -ErrorAction Ignore
}
#endregion
