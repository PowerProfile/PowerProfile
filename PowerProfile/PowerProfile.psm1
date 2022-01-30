#Requires -Version 5.1
#Requires -Modules 'PowerProfile.Core'

$ExecutionContext.SessionState.Module.OnRemove = {
    function Global:prompt {
        "PS $($ExecutionContext.SessionState.Path.CurrentLocation)$('>' * ($nestedPromptLevel + 1)) ";
        # .Link
        # https://go.microsoft.com/fwlink/?LinkID=225750
        # .ExternalHelp System.Management.Automation.dll-help.xml
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

if ($null -ne $ExecutionContext.SessionState.Module.PrivateData.PSData.Prerelease) {
    $Global:PoProfilePrerelease = $true
}
#endregion

#region Profiles
function Initialize-Profiles {
    Write-PoProfileProgress -ProfileTitle 'Loading profile'

    #region User functions
    if ((Get-PoProfileContent).Functions.Count -gt 0) {
        New-Module -Name 'PowerProfile-Dyn.Functions' -ScriptBlock {
            $ErrorActionPreference = 'Stop'

            Write-PoProfileItemProgress -ItemTitle 'Functions'

            :FunctionNames foreach ($FunctionFullName in (Get-PoProfileContent).Functions.Keys) {
                $FunctionIsVisible = $false

                if ($FunctionFullName -match '(?i)^([0-9\w- ]+)((?:\.\w+)+)?\.(\w+)$') {
                    $FunctionName = $Matches[1]
                    if ($null -ne $Matches[2]) {

                        :FunctionProperties switch ($Matches[2].Substring(1).Split('.')) {

                            Visible {
                                $FunctionIsVisible = $true
                            }

                            Setup {
                                if (
                                    $IsCommand -or
                                    $null -ne $env:PSLVL -or
                                    $IsNonInteractive -or
                                    $null -ne $PSDebugContext
                                ) {
                                    continue FunctionNames
                                }

                                # Do not run any setup with root privileges
                                #   to avoid file permission hickups on *Unix
                                if (
                                    -Not $IsWindows -and
                                    $null -ne $env:IsElevated
                                ) {
                                    continue FunctionNames
                                }
                            }

                            Interactive {
                                if (
                                    (
                                        $IsCommand -and
                                        -Not $IsNoExit
                                    ) -or
                                    $IsNonInteractive
                                ) {
                                    continue FunctionNames
                                }
                            }

                            NonInteractive {
                                if (-Not $IsNonInteractive) {
                                    continue FunctionNames
                                }
                            }

                            Command {
                                if (-Not $IsCommand) {
                                    continue FunctionNames
                                }
                            }

                            NoCommand {
                                if ($IsCommand) {
                                    continue FunctionNames
                                }
                            }

                            CommandNoExit {
                                if (
                                    -Not $IsCommand -or
                                    -Not $IsNoExit
                                ) {
                                    continue FunctionNames
                                }
                            }

                            Login {
                                if (-Not $IsLogin) {
                                    continue FunctionNames
                                }
                            }

                            NoLogin {
                                if ($IsLogin) {
                                    continue FunctionNames
                                }
                            }

                            Elevated {
                                if ($null -eq $env:IsElevated) {
                                    continue FunctionNames
                                }
                            }

                            NotElevated {
                                if ($null -ne $env:IsElevated) {
                                    continue FunctionNames
                                }
                            }

                            Default {
                                Write-PoProfileItemProgress -ItemTextColor $PSStyle.Foreground.Magenta -Depth 1 -ItemText (($FunctionFullName -replace '\.[^.]*$','') + '?')
                                continue FunctionNames
                            }

                        }
                    }
                } else {
                    Write-PoProfileItemProgress -ItemTextColor $PSStyle.Foreground.BrightMagenta -Depth 1 -ItemText ($FunctionFullName -replace '\.[^.]*$','')
                    continue FunctionNames
                }

                try {
                    $null = . (Get-PoProfileContent).Functions.$FunctionFullName
                    if ($FunctionIsVisible) {
                        Write-PoProfileItemProgress -ItemTextColor $PSStyle.Foreground.Green -Depth 1 -ItemText $FunctionName
                    }
                }
                catch {
                    Write-PoProfileItemProgress -ItemTextColor $PSStyle.Foreground.BrightRed -Depth 1 -ItemText $FunctionName
                }
            }
            Export-ModuleMember -Function * -Alias * -Variable @()
        } | Import-Module -Global -DisableNameChecking
    }
    #endregion

    #region User profiles
    $ProfileId = 1
    foreach ($CurrentProfile in @(Get-PoProfileProfilesList)) {
        if ($null -eq (Get-PoProfileContent).Profiles.$CurrentProfile) {
            $ProfileId++
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

        Set-PoProfileState -Name 'CurrentProfile' -Value $CurrentProfile

        New-Module -Name $DynModName -ScriptBlock {
            $ErrorActionPreference = 'Stop'

            $CurrentProfile = Get-PoProfileState 'CurrentProfile'
            $SetupState = Get-PoProfileState ('PoProfile.Setup.'+$CurrentProfile)

            :ScriptNames foreach ($ScriptFullName in ((Get-PoProfileContent).Profiles.$CurrentProfile.keys | Sort-Object)) {

                $ScriptIsHidden = $false
                $ScriptHasOutput = $false
                $ScriptIsSetup = $false

                if ($ScriptFullName -match '(?i)^([0-9]{4,})?((?:\.\w+)+)?-?([\w ]+)((?:\.\w+)+)?\.(\w+)$') {
                    if ($null -ne $Matches[1]) {
                        [decimal]$ScriptSortingNumber = $Matches[1]
                    }
                    if ($null -ne $Matches[2]) {
                        $ScriptProviderDetails = $Matches[2].Substring(1).Split('.')
                    }
                    $ScriptName = $Matches[3] -replace '_',' '
                    if ($null -ne $Matches[4]) {

                        :ScriptProperties switch ($Matches[4].Substring(1).Split('.')) {

                            Hidden {
                                $ScriptIsHidden = $true
                            }

                            Output {
                                $ScriptHasOutput = $true
                            }

                            Setup {
                                if (
                                    $IsCommand -or
                                    $null -ne $env:PSLVL -or
                                    $IsNonInteractive -or
                                    $null -ne $PSDebugContext
                                ) {
                                    continue ScriptNames
                                }

                                # Do not run any setup with root privileges
                                #   to avoid file permission hickups on *Unix
                                if (
                                    -Not $IsWindows -and
                                    $null -ne $env:IsElevated
                                ) {
                                    continue ScriptNames
                                }

                                $ScriptIsSetup = $true
                            }

                            Interactive {
                                if (
                                    (
                                        $IsCommand -and
                                        -Not $IsNoExit
                                    ) -or
                                    $IsNonInteractive
                                ) {
                                    continue ScriptNames
                                }
                            }

                            NonInteractive {
                                if (-Not $IsNonInteractive) {
                                    continue ScriptNames
                                }
                            }

                            Command {
                                if (-Not $IsCommand) {
                                    continue ScriptNames
                                }
                            }

                            NoCommand {
                                if ($IsCommand) {
                                    continue ScriptNames
                                }
                            }

                            CommandNoExit {
                                if (
                                    -Not $IsCommand -or
                                    -Not $IsNoExit
                                ) {
                                    continue ScriptNames
                                }
                            }

                            Login {
                                if (-Not $IsLogin) {
                                    continue ScriptNames
                                }
                            }

                            NoLogin {
                                if ($IsLogin) {
                                    continue ScriptNames
                                }
                            }

                            Elevated {
                                if ($null -eq $env:IsElevated) {
                                    continue ScriptNames
                                }
                            }

                            NotElevated {
                                if ($null -ne $env:IsElevated) {
                                    continue ScriptNames
                                }
                            }

                        }
                    }
                } else {
                    Write-PoProfileProgress -ScriptTitle ($PSStyle.Foreground.BrightYellow + $PSStyle.BoldOff + '[Ignored] ' + $PSStyle.Foreground.White + $ScriptFullName + $PSStyle.Foreground.Yellow + ' (file name sorting number?)') -NoCounter
                    continue ScriptNames
                }

                if ($ScriptIsSetup) {
                    if ($null -eq $SetupState.$ScriptFullName) {
                        Add-Member -InputObject $SetupState -MemberType NoteProperty -Name $ScriptFullName -Value @{
                            ErrorMessage = @()
                            LastUpdate = $null
                            State = 'Incomplete'
                        }
                    } elseif($SetupState.$ScriptFullName.State -ne 'Complete') {
                        $SetupState.$ScriptFullName.ErrorMessage = @()
                        $SetupState.$ScriptFullName.State = 'Incomplete'
                    } else {
                        continue ScriptNames
                    }
                }

                if (-Not $ScriptIsHidden) {
                    Write-PoProfileProgress -ScriptTitle $ScriptName
                }

                try {
                    if ($ScriptHasOutput) {
                        . (Get-PoProfileContent).Profiles.$CurrentProfile.$ScriptFullName
                    } else {
                        $null = . (Get-PoProfileContent).Profiles.$CurrentProfile.$ScriptFullName
                    }
                }
                catch {
                    if (-Not $ScriptHasOutput) {
                        if ($ScriptIsHidden) {
                            Write-PoProfileProgress -ScriptTitle $ScriptName
                        }
                        Write-PoProfileProgress -ScriptTitle @(($_.Exception.Message).Trim() -split [System.Environment]::NewLine) -ScriptTitleType Error
                    }
                }

                if ($ScriptIsSetup) {
                    $SetupState.$ScriptFullName.LastUpdate = Get-Date
                }
            }

            Set-PoProfileState -Name ('PoProfile.Setup.'+$CurrentProfile) -Value $SetupState
        } | Import-Module -Global -DisableNameChecking

        $ProfileId++
    }
    #endregion

    Remove-PoProfileState 'CurrentProfile'
    Save-PoProfileState
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

    Write-PoProfileProgress -ProfileTitle 'INITIALIZATION COMPLETE' # just to get newline in case we had output before
}
#endregion
