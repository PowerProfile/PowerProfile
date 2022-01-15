#Requires -Version 5.1

#region Module Script Variables
if ($null -eq $PSStyle) {

    # Lazy support for PSStyle for PS version <7.2.0
    $e = [char]27
    $Script:PSStyle = [PSCustomObject]@{
        Reset = "$e[0m"
        BlinkOff = "$e[25m"
        Blink = "$e[5m"
        BoldOff = "$e[22m"
        Bold = "$e[1m"
        HiddenOff = "$e[28m"
        Hidden = "$e[8m"
        ReverseOff = "$e[27m"
        Reverse = "$e[7m"
        ItalicOff = "$e[23m"
        Italic = "$e[3m"
        UnderlineOff = "$e[24m"
        Underline = "$e[4m"
        StrikethroughOff = "$e[29m"
        Strikethrough = "$e[9m"
        Foreground = @{
            Black = "$e[30m"
            Red = "$e[31m"
            Green = "$e[32m"
            Yellow = "$e[33m"
            Blue = "$e[34m"
            Magenta = "$e[35m"
            Cyan = "$e[36m"
            White = "$e[37m"
            BrightBlack = "$e[90m"
            BrightRed = "$e[91m"
            BrightGreen = "$e[92m"
            BrightYellow = "$e[93m"
            BrightBlue = "$e[94m"
            BrightMagenta = "$e[95m"
            BrightCyan = "$e[96m"
            BrightWhite = "$e[97m"
        }
        Background = @{
            Black = "$e[40m"
            Red = "$e[41m"
            Green = "$e[42m"
            Yellow = "$e[43m"
            Blue = "$e[44m"
            Magenta = "$e[45m"
            Cyan = "$e[46m"
            White = "$e[47m"
            BrightBlack = "$e[100m"
            BrightRed = "$e[101m"
            BrightGreen = "$e[102m"
            BrightYellow = "$e[103m"
            BrightBlue = "$e[104m"
            BrightMagenta = "$e[105m"
            BrightCyan = "$e[106m"
            BrightWhite = "$e[107m"
        }
    }

    $Parameters = @{
        MemberType = 'ScriptMethod'
        InputObject = $PSStyle
        Name = 'FormatHyperlink'
        Value = {
            return $("$e]8;;"+$args[1]+"$e\"+$args[0]+"$e]8;;$e\")
        }
    }
    Add-Member @Parameters
}
#endregion

#region Functions: Config
function Set-PoProfileConfig {

<#
.SYNOPSIS
    Add/change/remove a PowerProfile config item

.DESCRIPTION
    Adds an item to the PowerProfile configuration

.PARAMETER Name
    Key name of the state item

.PARAMETER Value
    Value of the state item

.PARAMETER Remove
    Removes the desired state item

.LINK
    https://PowerProfile.sh/
#>

    [CmdletBinding(DefaultParameterSetName='SetKey')]
    Param(
        [Parameter(Mandatory=$True,Position=0,ParameterSetName='SetKey')]
        [Parameter(Mandatory=$True,Position=0,ParameterSetName='RemoveKey')]
        [string]$Name,

        [Parameter(Mandatory=$True,Position=1,ParameterSetName='SetKey')]
        [AllowEmptyString()]
        [AllowNull()]
        $Value,

        [Parameter(Mandatory=$True,ParameterSetName='RemoveKey')]
        [switch]$Remove
    )

    if ($Value -eq [bool]::TrueString -or $Value -eq [bool]::FalseString) {
        $Value = [System.Convert]::ToBoolean($Value)
    }
    if ($Remove) {
        $PoProfileConfig.PSObject.Properties.Remove($Name)
    }
    elseif ($null -eq $PoProfileConfig.PSObject.Properties.Item($Name)) {
        $PoProfileConfig | Add-Member -MemberType NoteProperty -Name $Name -Value $Value
    }
    else {
        $PoProfileConfig.$Name = $Value
    }

    $p = [System.IO.Path]::Combine(
            $env:XDG_CONFIG_HOME,
            $(
                if ($IsWindows) {
                    'PowerShell'
                } else {
                    'powershell'}
            ),
            'Modules',
            'PowerProfile',
            'PowerProfile.state.json'
        )

    if (($PoProfileConfig.PSObject.Properties).Count -gt 0) {
        $baseDir = Split-Path -Path $p
        if (-Not ([System.IO.Directory]::Exists($baseDir))) {
            $null = New-Item -Type Container -Force $baseDir -ErrorAction Stop
        }
        ConvertTo-Json $PoProfileConfig -Compress | Set-Content -Path $p -Encoding ASCII
    } elseif ([System.IO.File]::Exists($p)) {
        Remove-Item -Path $p -ErrorAction Ignore
    }
}

function Get-PoProfileConfig {

<#
.SYNOPSIS
    Get PowerProfile config

.DESCRIPTION
    Reads the PowerProfile config

.PARAMETER Name
    Return the value of a specific config item only

.OUTPUTS
    String, when specifying $Name, otherwise PSObject.

.LINK
    https://PowerProfile.sh/
#>

    [CmdletBinding()]
    Param(
        [string]$Name
    )

    $p = [System.IO.Path]::Combine(
        $env:XDG_STATE_HOME,
        $(
            if ($IsWindows) {
                'PowerShell'
            } else {
                'powershell'
            }
        ),
        'Modules',
        'PowerProfile',
        'PowerProfile.state.json'
    )

    if (-Not (Get-Variable -Scope Script -Name 'PoProfileState' -ErrorAction Ignore)) {
        if ([System.IO.File]::Exists($p)) {
            $PoProfileConfig = [System.IO.File]::ReadAllText($p) | ConvertFrom-Json -ErrorAction Ignore
        } else {
            $PoProfileConfig = New-Object PSObject
        }
    }

    if ($Name -and $PoProfileConfig.$Name) {
        $PoProfileConfig.$Name
    } else {
        $PoProfileConfig
    }
}

function Remove-PoProfileConfig {

<#
.SYNOPSIS
    Remove PowerProfile config item

.DESCRIPTION
    Removes a state item from PowerProfile

.PARAMETER Name
    Key name of the state item

.LINK
    https://PowerProfile.sh/
#>

    [CmdletBinding()]
    [OutputType([System.Management.Automation.PSObject])]
    Param(
        [Parameter(Mandatory=$True)]
        [string]$Name
    )

    Try {
        Set-PoProfileConfig -Remove -Name $Name
    }
    Catch {
        Write-Error $_.Exception.Message
        return
    }
}
#endregion

#region Functions: State
function Set-PoProfileState {

<#
.SYNOPSIS
    Add/change/remove a PowerProfile state item

.DESCRIPTION
    Adds an item to the PowerProfile state

.PARAMETER Name
    Key name of the state item

.PARAMETER Value
    Value of the state item

.PARAMETER Remove
    Removes the desired state item

.LINK
    https://PowerProfile.sh/
#>

    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$True,Position=0,ParameterSetName='SetKey')]
        [Parameter(Mandatory=$True,Position=0,ParameterSetName='RemoveKey')]
        [string]$Name,

        [Parameter(Mandatory=$True,Position=1,ParameterSetName='SetKey')]
        [AllowEmptyString()]
        [AllowNull()]
        $Value,

        [Parameter(Mandatory=$True,ParameterSetName='RemoveKey')]
        [switch]$Remove
    )

    if (-Not (Get-Variable -Scope Script -Name 'PoProfileState' -ErrorAction Ignore)) {
        Get-PoProfileState
    }

    if ($Value -eq [bool]::TrueString -or $Value -eq [bool]::FalseString) {
        $Value = [System.Convert]::ToBoolean($Value)
    }
    if ($Remove) {
        $PoProfileState.PSObject.Properties.Remove($Name)
    }
    elseif ($null -eq $PoProfileState.PSObject.Properties.Item($Name)) {
        $PoProfileState | Add-Member -MemberType NoteProperty -Name $Name -Value $Value
    }
    else {
        $PoProfileState.$Name = $Value
    }

    $p = [System.IO.Path]::Combine(
        $env:XDG_STATE_HOME,
        $(
            if ($IsWindows) {
                'PowerShell'
            } else {
                'powershell'
            }
        ),
        'Modules',
        'PowerProfile',
        'PowerProfile.state.json'
    )

    if (($PoProfileState.PSObject.Properties).Count -gt 0) {
        $baseDir = Split-Path -Path $p
        if (-Not ([System.IO.Directory]::Exists($baseDir))) {
            $null = New-Item -Type Container -Force $baseDir -ErrorAction Stop
        }
        ConvertTo-Json $PoProfileState -Compress | Set-Content -Path $p -Encoding ASCII
    } elseif ([System.IO.File]::Exists($p)) {
        Remove-Item -Path $p -ErrorAction Ignore
    }
}

function Get-PoProfileState {

<#
.SYNOPSIS
    Get PowerProfile state

.DESCRIPTION
    Reads the PowerProfile state

.PARAMETER Name
    Return the value of a specific state item only

.OUTPUTS
    String, when specifying $Name, otherwise PSObject.

.LINK
    https://PowerProfile.sh/
#>

    [CmdletBinding()]
    Param(
        [string]$Name
    )

    $p = [System.IO.Path]::Combine(
        $env:XDG_STATE_HOME,
        $(
            if ($IsWindows) {
                'PowerShell'
            } else {
                'powershell'
            }
        ),
        'Modules',
        'PowerProfile',
        'PowerProfile.state.json'
    )

    if (-Not (Get-Variable -Scope Script -Name 'PoProfileState' -ErrorAction Ignore)) {
        if ([System.IO.File]::Exists($p)) {
            $Script:PoProfileState = [System.IO.File]::ReadAllText($p) | ConvertFrom-Json -ErrorAction Ignore
        } else {
            $Script:PoProfileState = New-Object PSObject
        }
    }

    if ($Name) {
        if ($PoProfileState.$Name) {
            return $PoProfileState.$Name
        } else {
            return $null
        }
    } else {
        return $PoProfileState
    }
}

function Remove-PoProfileState {

<#
.SYNOPSIS
    Remove PowerProfile state item

.DESCRIPTION
    Removes a state item from PowerProfile

.PARAMETER Name
    Key name of the state item

.LINK
    https://PowerProfile.sh/
#>

    [CmdletBinding()]
    [OutputType([System.Management.Automation.PSObject])]
    Param(
        [Parameter(Mandatory=$True)]
        [string]$Name
    )

    Try {
        Set-PoProfileState -Remove -Name $Name
    }
    Catch {
        Write-Error $_.Exception.Message
        return
    }
}

function Reset-PoProfileState {

<#
.SYNOPSIS
    Resets PowerProfile state on the local machine

.DESCRIPTION
    Wipes the entire PowerProfile state on the local machine

.LINK
    https://PowerProfile.sh/
#>

    [CmdletBinding(SupportsShouldProcess,ConfirmImpact='High')]
    Param(
        [switch]$Force
    )

    $p = [System.IO.Path]::Combine(
        $env:XDG_STATE_HOME,
        $(
            if ($IsWindows) {
                'PowerShell'
            } else {
                'powershell'
            }
        ),
        'Modules',
        'PowerProfile',
        'PowerProfile.state.json'
    )

    if ([System.IO.File]::Exists($p)) {
        if ($Force -or $PSCmdlet.ShouldProcess($p)) {
            Remove-Item -Path $p -ErrorAction Ignore -Confirm:$false
            Remove-Variable -Scope Script -Name PoProfileState -ErrorAction Ignore -Confirm:$false
            New-Variable -Scope Script -Name PoProfileState -Value (New-Object PSObject)
        }
    }
}
#endregion

#region Functions: Utilitites
function Get-PoProfileSubDirs {
    [OutputType([array])]
    Param (
        [Parameter(Mandatory=$true)]
        [string]${Name},

        [bool]${Platform}=$true,

        [bool]${Architecture}=$true,

        [bool]${Machine}=$true,

        [ValidateSet('None','Core','Desktop','All')]
        [string]${PSEditions}='All'
    )

    $PlatformDirectory = '_Platform_' + $(if ($IsMacOS) {'macOS'} elseif ($IsLinux) {'Linux'} else {'Windows'})
    $ArchDirectory = '_Arch_' + ($env:PROCESSOR_ARCHITECTURE).ToUpper()
    $MachineDirectory = '_Machine_' + ($env:COMPUTERNAME).ToUpper()

    # List profile directories in scope
    @(
        if ($Architecture) {$ArchDirectory}
        if ($Machine) {$MachineDirectory}
        if ($Platform) {
            if ($IsCoreCLR -or ($Name -notmatch '^Profile_.*')) {
                if (-Not $IsWindows) {
                    '_Platform_NonWindows'
                    if ($Architecture) {[System.IO.Path]::Combine('_Platform_NonWindows',$ArchDirectory)}
                }
                $PlatformDirectory
                if ($Architecture) {[System.IO.Path]::Combine($PlatformDirectory,$ArchDirectory)}
            }
        }
        if ($IsCoreCLR) {
            if (($PSEditions -eq 'All') -or ($PSEditions -eq 'Core')) {
                '_PSEdition_Core'
                if ($Architecture) {[System.IO.Path]::Combine('_PSEdition_Core',$ArchDirectory)}
                if ($Machine) {[System.IO.Path]::Combine('_PSEdition_Core',$MachineDirectory)}
            }
            if ($IsWindows) {
                if (($PSEditions -eq 'All') -or ($PSEditions -eq 'Core')) {
                    ([System.IO.Path]::Combine($PlatformDirectory,'_PSEdition_Core'))
                    if ($Architecture) {[System.IO.Path]::Combine($PlatformDirectory,'_PSEdition_Core',$ArchDirectory)}
                }
                if (($PSEditions -eq 'All') -or ($PSEditions -eq 'Desktop')) {
                    ([System.IO.Path]::Combine($PlatformDirectory,'_PSEdition_Desktop'))
                    if ($Architecture) {[System.IO.Path]::Combine($PlatformDirectory,'_PSEdition_Desktop',$ArchDirectory)}
                    if ($Machine) {[System.IO.Path]::Combine($PlatformDirectory,'_PSEdition_Desktop',$MachineDirectory)}
                }
            }
        }
    )
}

function Add-EnvPath {

<#
.SYNOPSIS
    Brief synopsis about the function.

.DESCRIPTION
    Detailed explanation of the purpose of this function.
#>

    [CmdletBinding(PositionalBinding=$false)]
    [OutputType([System.Void])]
    Param(
        [string]$Name='PATH',

        [Parameter(Mandatory=$true,Position=0)]
        [AllowEmptyString()]
        [string[]]$Value,

        [switch]$Prepend
    )

    $p = [System.Environment]::GetEnvironmentVariable($Name)
    if ($p) {
        [System.Collections.ArrayList]$p = $p.Split([System.IO.Path]::PathSeparator)
    } else {
        [System.Collections.ArrayList]$p = @()
    }

    foreach ($v in $Value) {
        foreach ($i in $v.Split([System.IO.Path]::PathSeparator)) {
            if ($i -notin $p) {
                if ($Prepend) {
                    $null = $p.Insert(0,$i)
                } else {
                    $null = $p.Add($i)
                }
            }
        }
    }

    [System.Environment]::SetEnvironmentVariable(
        $Name,
        (
            [System.Environment]::ExpandEnvironmentVariables($p -Join [System.IO.Path]::PathSeparator)),
            [System.EnvironmentVariableTarget]::Process
        )
}

function Resolve-RealPath {
<#
.SYNOPSIS
    Implementation of Unix realpath().

.DESCRIPTION
    Implementation of Unix realpath().

.PARAMETER Path
    Path must exist

.LINK
    https://github.com/PowerProfile/psprofile-common
#>

    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Position = 0, Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [Alias('FullName')]
        [string] $Path
    )

    $Path = $Path | Resolve-Path
    if (-Not ([System.IO.File]::Exists($Path)) -and -Not ([System.IO.Directory]::Exists($Path))) {
        return $Path
    }

    [string[]] $parts = ($Path.TrimStart([IO.Path]::DirectorySeparatorChar).Split([IO.Path]::DirectorySeparatorChar))
    [string] $realPath = ''
    foreach ($part in $parts) {
        $changedPath = $false

        # Change to the path to allow resolving
        # relative path in link
        if ([System.IO.Directory]::Exists($realPath)) {
            Push-Location $realPath
            $changedPath = $true
        }

        $realPath += [string]([IO.Path]::DirectorySeparatorChar + $part)
        $item = Get-Item $realPath -Force
        if ($item.Target) {
            $realPath = $item.Target | Resolve-Path
        }

        if ($changedPath) {
            Pop-Location
        }
    }

    return $realPath
}

function Get-PoProfileContent {
    [OutputType([PSCustomObject])]
    Param()
    if ($null -eq $Script:PoProfileContent) {
        $Parameters = @{
            Directories = @(
                $(
                    $p = [System.IO.Path]::Combine($PSScriptRoot,'PSProfile')
                    if ([System.IO.Directory]::Exists($p)) {
                        $p
                    }
                )
                $(
                    foreach ($d in @(Get-Module -ListAvailable -Name ([System.IO.Path]::Combine($PROFILEHOME,'Modules','PowerProfile.*.*')))) {
                        $p = [System.IO.Path]::Combine(
                            (Split-Path $d.Path),
                            'PSProfile'
                        )
                        if ([System.IO.Directory]::Exists($p)) {
                            $p
                        }
                    }
                )
                $PROFILEHOME
            )
            Profiles = @(Get-PoProfileProfilesList)
        }
        $Script:PoProfileContent = Find-PoProfileContent @Parameters
    }
    $PoProfileContent
}

function Get-PoProfileProfilesList {
    [OutputType([array])]
    Param()

    if ($null -eq $Script:PoProfileProfilesList) {
        $Script:PoProfileProfilesList = @(
            'Profile'
            'Profile_' + (($env:LC_PSHOST.ToLower() -replace ' ','') -replace '_','')
            if ($null -ne $env:TERM_PROGRAM -and $env:TERM_PROGRAM -ne $env:PSHOST_PROGRAM) {
                'Profile_' + (($env:LC_TERMINAL.ToLower() -replace ' ','') -replace '_','')
            }
        )
    }
    $PoProfileProfilesList
}

function Find-PoProfileContent {
    [OutputType([PSCustomObject])]
    param(
        [string[]]$Directories=$PROFILEHOME,
        [string[]]$Profiles='Profile'
    )

    [PSCustomObject]$return = @{
        Profiles = @{}
        Config = @{}
        PoProfileConfig = @{}
        Functions = [ordered]@{}
        Modules = @()
        Scripts = @()
    }
    $keys = @('Config','Functions','Modules','Scripts')

    # PSProfile directory or PowerProfile bundle directories
    foreach ($Directory in $Directories) {
        if ($Directory -ne $PROFILEHOME) {
            $p = [System.IO.Path]::Combine($Directory,'Modules')
            if (
                [System.IO.Directory]::Exists($p) -and
                @([System.IO.Directory]::EnumerateDirectories($p,'*','TopDirectoryOnly')).Count -gt 0
            ) {
                $return.Modules += $p
            }
            $p = [System.IO.Path]::Combine($Directory,'Scripts')
            if (
                [System.IO.Directory]::Exists($p) -and
                @([System.IO.Directory]::EnumerateFiles($p,'*.ps1','TopDirectoryOnly')).Count -gt 0
            ) {
                $return.Scripts += $p
            }
        }

        # User Profiles
        foreach ($PoPr in $Profiles) {
            $SubDirs = @('') + @(Get-PoProfileSubDirs -Name (Split-Path -Leaf $PoPr) -PSEditions $(if ($IsCoreCLR) {'Core'} else {'Desktop'}))

            foreach ($SubDir in $SubDirs) {
                $p = [System.IO.Path]::Combine($Directory,$PoPr,$SubDir)
                if ([System.IO.Directory]::Exists($p)) {
                    [string[]]$files = [System.IO.Directory]::EnumerateFiles($p,'*.ps1','TopDirectoryOnly')
                    [array]::Sort($files)
                    foreach ($file in $files) {
                        if ($file -match '\.Test\.ps1$') {
                            continue
                        }
                        if( $null -eq $return.Profiles.$PoPr ) {
                            $return.Profiles.$PoPr = [ordered]@{}
                        }
                        $Node = Split-Path -Leaf $file
                        $return.Profiles.$PoPr.$Node = $file
                    }

                    foreach ($key in $keys) {
                        $p = [System.IO.Path]::Combine($Directory,$PoPr,$SubDir,$key)
                        if ([System.IO.Directory]::Exists($p)) {
                            switch -Exact ($key) {

                                Config {

                                    # Top directory for PowerProfile specific config only
                                    [string[]]$files = [System.IO.Directory]::EnumerateFiles($p,'*','TopDirectoryOnly')
                                    [array]::Sort($files)
                                    foreach ($file in $files) {
                                        $Node = Split-Path -Leaf $file
                                        if( $null -eq $return.'PoProfileConfig'.$PoPr ) {
                                            $return.'PoProfileConfig'.$PoPr = [ordered]@{}
                                        }
                                        $return.'PoProfileConfig'.$PoPr.$Node = $file
                                    }

                                    # Sub directories for 3rd-party configuration assets
                                    [string[]]$dirs = [System.IO.Directory]::EnumerateDirectories($p,'*','TopDirectoryOnly')
                                    foreach ($dir in $dirs) {
                                        $Node = Split-Path -Leaf $dir
                                        if( $null -eq $return.$key.$PoPr ) {
                                            $return.$key.$PoPr = @{}
                                        }
                                        [string[]]$files = [System.IO.Directory]::EnumerateFiles($dir,'*','TopDirectoryOnly')
                                        [array]::Sort($files)
                                        foreach ($file in $files) {
                                            $fNode = Split-Path -Leaf $file
                                            if( $null -eq $return.$key.$PoPr.$Node ) {
                                                $return.$key.$PoPr.$Node = [ordered]@{}
                                            }
                                            $return.$key.$PoPr.$Node.$fNode = $file
                                        }
                                    }

                                    Break
                                }

                                Functions {
                                    [string[]]$files = [System.IO.Directory]::EnumerateFiles($p,'*.ps1','AllDirectories')
                                    [array]::Sort($files)
                                    foreach ($file in $files) {
                                        if ($file -match '\.Test\.ps1$') {
                                            continue
                                        }
                                        $Node = Split-Path -Leaf $file
                                        $return.$key.$Node = $file
                                    }

                                    Break
                                }

                                Modules {
                                    if (@([System.IO.Directory]::EnumerateDirectories($p,'*','TopDirectoryOnly')).Count -gt 0) {
                                        $return.$key += $p
                                    }

                                    Break
                                }

                                Scripts {
                                    if (@([System.IO.Directory]::EnumerateFiles($p,'*.ps1','TopDirectoryOnly')).Count -gt 0) {
                                        $return.$key += $p
                                    }

                                    Break
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    $return
}
#endregion

#region Functions: Write
function Write-PoProfileItemProgress {
    Param(
        [string]$ProfileTitle,

        [string]$ItemTitle,

        [AllowEmptyString()]
        [string]$ItemCategory,

        [string]$ItemText,
        [string]$ItemTextColor=$PSStyle.Foreground.BrightBlack,
        [Int]$Depth
    )

    if ($IsCommand -or $IsNonInteractive -or ($null -ne $env:PSLVL)) {
        return
    }

    $Script:PoProfileProgressScriptCategoryShowed = $false
    $Script:PoProfileProgressScriptTitleShowed = $false

    if ($PSBoundParameters.ContainsKey('ProfileTitle') -and $ProfileTitle -ne $PoProfileProgressTitle) {
        if ($PoProfileProgressItemTextShowed) {
            Write-Host ''
        }
        if ($PoProfileProgressItemTitleShowed) {
            Write-Host ''
        }
        $Script:PoProfileProgressTitleShowed = $false
        $Script:PoProfileProgressItemTitleShowed = $false
        $Script:PoProfileProgressItemTextShowed = $false
        $Script:PoProfileProgressDepth = 1
        $Script:PoProfileProgressCounter = 1
        $Script:PoProfileProgressTitle = $ProfileTitle
    }
    if ($PSBoundParameters.ContainsKey('ItemTitle') -and $ItemTitle -ne $PoProfileProgressItemTitle) {
        if ($PoProfileProgressItemTextShowed) {
            Write-Host ''
        }
        $Script:PoProfileProgressItemTitleShowed = $false
        $Script:PoProfileProgressItemCategoryShowed = $false
        $Script:PoProfileProgressItemTextShowed = $false
        $Script:PoProfileProgressDepth = 1
        $Script:PoProfileProgressItemTitle = $ItemTitle
    }
    if ($PSBoundParameters.ContainsKey('ItemCategory') -and $ItemCategory -ne $PoProfileProgressItemCategory) {
        if ($PoProfileProgressItemTextShowed) {
            Write-Host ''
        }
        $Script:PoProfileProgressItemCategoryShowed = $false
        $Script:PoProfileProgressItemTextShowed = $false
        $Script:PoProfileProgressItemCategory = $ItemCategory
    }
    if ($PSBoundParameters.ContainsKey('Depth') -and $Depth -ge 1 -and $Depth -ne $PoProfileProgressDepth) {
        $Script:PoProfileProgressDepth = $Depth
    }
    if (-not $PSBoundParameters.ContainsKey('ItemText')) {
        return
    }

    if (-Not $PoProfileProgressTitleShowed) {
        $Script:PoProfileProgressTitleShowed = $true
        Write-Host ($PSStyle.Foreground.BrightGreen + $PoProfileProgressTitle + ':' + $PSStyle.Reset)
    }

    if (-Not $PoProfileProgressItemTitleShowed) {
        $Script:PoProfileProgressItemTitleShowed = $true
        $Number = (' ' * (3 - (@($PoProfileProgressCounter.ToString().Length, 3) | Measure-Object -Minimum).Minimum)) + $PoProfileProgressCounter
        $Script:PoProfileProgressCounter++
        Write-Host ($PSStyle.Foreground.BrightWhite + $PSStyle.Bold + "${Number}. ${Script:PoProfileProgressItemTitle}:" + $PSStyle.Reset)
    }

    $Indentation = ' ' * (5 + $Script:PoProfileProgressDepth)

    if (-Not $PoProfileProgressItemCategoryShowed) {
        $Script:PoProfileProgressItemCategoryShowed = $true
        if ($PoProfileProgressItemCategory -and '' -ne $PoProfileProgressItemCategory) {
            $Script:PoProfileProgressDepth++
            Write-Host ($Indentation + $PSStyle.Foreground.Yellow + $PoProfileProgressItemCategory + ':' + $PSStyle.Reset)
            $Indentation = " $Indentation"
        }
    }

    if ($PoProfileProgressItemTextShowed) {
        $ItemText = " ${ItemText}"
    } elseif ($PoProfileProgressItemCategoryShowed) {
        $ItemText = "${Indentation}${ItemText}"
    } else {
        $ItemText = "${Indentation} ${ItemText}"
    }
    $Script:PoProfileProgressItemTextShowed = $true
    Write-Host "${ItemTextColor}${ItemText}$($PSStyle.Reset)" -NoNewline
}

function Write-PoProfileProgress {
    Param(
        [string]$ProfileTitle,

        [AllowEmptyString()]
        [string]$ScriptCategory,

        [string[]]$ScriptTitle,

        [ValidateSet('Progress','Verbose','Note','Confirmation','Information','Warning','Error')]
        [string]${ScriptTitleType}='Progress',

        [switch]$NoCounter
    )

    if ($IsCommand -or $IsNonInteractive -or ($null -ne $env:PSLVL)) {
        return
    }

    if ($PoProfileProgressItemTextShowed) {
        Write-Host ''
    }
    $Script:PoProfileProgressItemTitleShowed = $false
    $Script:PoProfileProgressItemCategoryShowed = $false
    $Script:PoProfileProgressItemTextShowed = $false

    if ($PSBoundParameters.ContainsKey('ProfileTitle') -and $ProfileTitle -ne $PoProfileProgressTitle) {
        if ($PoProfileProgressScriptTitleShowed) {
            Write-Host ''
        }
        $Script:PoProfileProgressTitleShowed = $false
        $Script:PoProfileProgressScriptTitleShowed = $false
        $Script:PoProfileProgressDepth = 1
        $Script:PoProfileProgressCounter = 1
        $Script:PoProfileProgressTitle = $ProfileTitle
    }
    if ($PSBoundParameters.ContainsKey('ScriptCategory') -and $ScriptCategory -ne $PoProfileProgressScriptCategory) {
        $Script:PoProfileProgressScriptCategoryShowed = $false
        $Script:PoProfileProgressScriptTitleShowed = $false
        $Script:PoProfileProgressScriptCategory = $ScriptCategory
    }
    if (-not $PSBoundParameters.ContainsKey('ScriptTitle')) {
        return
    }

    if (-Not $PoProfileProgressTitleShowed) {
        $Script:PoProfileProgressTitleShowed = $true
        Write-Host ($PSStyle.Foreground.BrightGreen + $PoProfileProgressTitle + ':' + $PSStyle.Reset)
    }

    if (-Not $PoProfileProgressScriptCategoryShowed) {
        $Script:PoProfileProgressScriptCategoryShowed = $true
        if ($PoProfileProgressScriptCategory -and '' -ne $PoProfileProgressScriptCategory) {
            Write-Host (' ' + $PSStyle.Foreground.Yellow + $PoProfileProgressScriptCategory + ':' + $PSStyle.Reset)
        }
    }

    $Script:PoProfileProgressScriptTitleShowed = $true

    if ($ScriptTitleType -eq 'Confirmation') {
        $Color = $PSStyle.Foreground.BrightGreen
        $ShowSquare = '✔'
    } elseif ($ScriptTitleType -eq 'Information') {
        $Color = $PSStyle.Foreground.BrightCyan
        $ShowSquare = 'i'
    } elseif ($ScriptTitleType -eq 'Warning') {
        $Color = $PSStyle.Foreground.BrightYellow
        $ShowSquare = '!'
    } elseif ($ScriptTitleType -eq 'Error') {
        $Color = $PSStyle.Foreground.BrightRed
        $ShowSquare = 'X'
    } elseif ($ScriptTitleType -eq 'Note') {
        $Color = $PSStyle.Foreground.BrightBlue
    } elseif ($ScriptTitleType -eq 'Verbose') {
        $Color = $PSStyle.Foreground.BrightBlack
    } else {
        $Color = $PSStyle.Foreground.White
    }

    if ($ShowSquare) {
        Write-Host (
            "  $Color" + $PSStyle.Reverse + " $ShowSquare " + $PSStyle.ReverseOff +
            $(
                if ($Color -eq $PSStyle.Foreground.BrightRed) { $Color = $PSStyle.Foreground.Red }
                $count = 1
                $Color + $(
                    foreach ($Line in $ScriptTitle) {
                        if ($count -eq 1) {
                            $Prefix = ' '
                        } else {
                            $Prefix = '     '
                        }
                        "${Prefix}${Line}" + [System.Environment]::NewLine
                        $count++
                    }
                )
            ) + $PSStyle.Reset
        )
    } else {
        if ($NoCounter) {
            $Prefix = '  '
            $Suffix = ''
        } else {
            $Prefix =  (' ' * (3 - (@($PoProfileProgressCounter.ToString().Length, 3) | Measure-Object -Minimum).Minimum)) + $PoProfileProgressCounter + '. '
            $Script:PoProfileProgressCounter++
            $Suffix = ' ...'
        }
        Write-Host ( $PSStyle.Bold + "${Prefix}${ScriptTitle}${Suffix}" + $PSStyle.Reset)
    }
}
#endregion

#region Functions: PowerShell Core
function pwsh {
    [System.Collections.ArrayList]$a = $args
    if ($IsLogin -and $a[0] -notmatch '(?i)^-L(o(g(in?)?)?)?$') {
        $a.Insert(0,'-l')
    }
    if ($a -notmatch '^-NoL.*') {
        if ($IsLogin) {
            $a.Insert(1,'-nol')
        } else {
            $a.Insert(0,'-nol')
        }
    }
    (Get-Process -Id $PID).Path + " $a" | Invoke-Expression
}
Set-Alias -Name pwsh-preview -Value pwsh
#endregion

#region Functions: PowerShellGet
function Invoke-PoProfileInstallPSResource {
    [Alias('Install-PSResource')]
    [CmdletBinding(DefaultParameterSetName='NameParameterSet', SupportsShouldProcess=$true, ConfirmImpact='Medium', HelpUri='https://go.microsoft.com/fwlink/?LinkID=398573')]
    param(
        [Parameter(ParameterSetName='NameParameterSet', Mandatory=$true, Position=0, ValueFromPipelineByPropertyName=$true)]
        [ValidateNotNullOrEmpty()]
        [string[]]
        ${Name},

        [Parameter(ParameterSetName='InputObject', Mandatory=$true, Position=0, ValueFromPipeline=$true, ValueFromPipelineByPropertyName=$true)]
        [ValidateNotNull()]
        [psobject[]]
        ${InputObject},

        [Parameter(ParameterSetName='NameParameterSet', ValueFromPipelineByPropertyName=$true)]
        [ValidateNotNull()]
        [string]
        ${MinimumVersion},

        [Parameter(ParameterSetName='NameParameterSet', ValueFromPipelineByPropertyName=$true)]
        [ValidateNotNull()]
        [string]
        ${MaximumVersion},

        [Parameter(ParameterSetName='NameParameterSet', ValueFromPipelineByPropertyName=$true)]
        [ValidateNotNull()]
        [string]
        ${RequiredVersion},

        [Parameter(ParameterSetName='NameParameterSet')]
        [ValidateNotNullOrEmpty()]
        [string[]]
        ${Repository},

        [Parameter(ValueFromPipelineByPropertyName=$true)]
        [pscredential]
        [System.Management.Automation.CredentialAttribute()]
        ${Credential},

        [ValidateSet('CurrentUser','AllUsers')]
        [string]
        ${Scope},

        [Parameter(ValueFromPipelineByPropertyName=$true)]
        [ValidateNotNullOrEmpty()]
        [uri]
        ${Proxy},

        [Parameter(ValueFromPipelineByPropertyName=$true)]
        [pscredential]
        [System.Management.Automation.CredentialAttribute()]
        ${ProxyCredential},

        [switch]
        ${AllowClobber},

        [switch]
        ${SkipPublisherCheck},

        [switch]
        ${Force},

        [Parameter(ParameterSetName='NameParameterSet')]
        [switch]
        ${AllowPrerelease},

        [switch]
        ${AcceptLicense},

        [switch]
        ${PassThru})

    begin
    {
        try {
            if (
                (-Not $PSBoundParameters.ContainsKey('Scope')) -and
                $env:IsProfileRedirected
            ) {
                $PSBoundParameters['Scope'] = 'AllUsers'
            }

            # Implicitly use PSGallery if there are many source repositories
            # for the same module name
            $PSRepos = Find-Module $PSBoundParameters['Name']
            if (
                (-Not $PSBoundParameters.ContainsKey('Repository')) -and
                ($PSRepos.Count -gt 1) -and
                ($PSRepos.Repository -contains 'PSGallery')
            ) {
                $PSBoundParameters['Repository'] = 'PSGallery'
            }

            $outBuffer = $null
            if ($PSBoundParameters.TryGetValue('OutBuffer', [ref]$outBuffer))
            {
                $PSBoundParameters['OutBuffer'] = 1
            }

            $wrappedCmd = $ExecutionContext.InvokeCommand.GetCommand('Install-PSResource', [System.Management.Automation.CommandTypes]::Function)
            $scriptCmd = {& $wrappedCmd @PSBoundParameters }

            $steppablePipeline = $scriptCmd.GetSteppablePipeline()
            $steppablePipeline.Begin($PSCmdlet)
        } catch {
            throw
        }
    }

    process
    {
        try {
            $steppablePipeline.Process($_)
        } catch {
            throw
        }
    }

    end
    {
        try {
            $steppablePipeline.End()
        } catch {
            throw
        }
    }
    <#

    .ForwardHelpTargetName Install-PSResource
    .ForwardHelpCategory Function

    #>
}
#endregion

#region System Environment
switch -Regex (@([System.Environment]::GetCommandLineArgs())) {
    '(?i)^-C(o(m(m(a(nd?)?)?)?)?)?$' {
        $Parameters = @{
            Scope = 'Script'
            Name = 'IsCommand'
            Value = $true
            Option = 'ReadOnly'
            Description = 'PowerShell was started with command line argument -Command'
        }
        Set-Variable @Parameters
        continue
    }
    '(?i)^-L(o(g(in?)?)?)?$' {
        $Parameters = @{
            Scope = 'Script'
            Name = 'IsLogin'
            Value = $true
            Option = 'ReadOnly'
            Description = 'PowerShell was started as a login shell'
        }
        Set-Variable @Parameters
        continue
    }
    '(?i)^-NoE(x(it?)?)?$' {
        $Parameters = @{
            Scope = 'Script'
            Name = 'IsNoExit'
            Value = $true
            Option = 'ReadOnly'
            Description = 'PowerShell was started with command line argument -NoExit'
        }
        Set-Variable @Parameters
        continue
    }
    '(?i)^-NonI(n(t(e(r(a(c(t(i(ve?)?)?)?)?)?)?)?)?)?$' {
        $Parameters = @{
            Scope = 'Script'
            Name = 'IsNonInteractive'
            Value = $true
            Option = 'ReadOnly'
            Description = 'PowerShell was explicitly started in non-interactive mode'
        }
        Set-Variable @Parameters
        continue
    }
}
if ($null -eq $IsCommand) {
    $Parameters = @{
        Scope = 'Script'
        Name = 'IsCommand'
        Value = $false
        Option = 'ReadOnly'
    }
    Set-Variable @Parameters
}
if ($null -eq $IsLogin) {
    $Parameters = @{
        Scope = 'Script'
        Name = 'IsLogin'
        Value = $false
        Option = 'ReadOnly'
    }
    Set-Variable @Parameters
}
if ($null -eq $IsNoExit) {
    $Parameters = @{
        Scope = 'Script'
        Name = 'IsNoExit'
        Value = $false
        Option = 'ReadOnly'
    }
    Set-Variable @Parameters
}
if ($null -eq $IsNonInteractive) {
    if ($null -eq [System.Environment]::UserInteractive) {
        $v = $true
    } else {
        $v = $false
    }
    $Parameters = @{
        Scope = 'Script'
        Name = 'IsNonInteractive'
        Value = $v
        Option = 'ReadOnly'
    }
    Set-Variable @Parameters
}

# Cross-platform compatibility for Windows PowerShell
if ($PSEdition -eq 'Desktop') {
    $Parameters = @{
        Scope = 'Script'
        Name = 'IsCoreCLR'
        Value = $false
        Option = 'ReadOnly'
    }
    Set-Variable @Parameters

    $Parameters = @{
        Scope = 'Script'
        Name = 'IsLinux'
        Value = $false
        Option = 'ReadOnly'
    }
    Set-Variable @Parameters

    $Parameters = @{
        Scope = 'Script'
        Name = 'IsMacOS'
        Value = $false
        Option = 'ReadOnly'
    }
    Set-Variable @Parameters

    $Parameters = @{
        Scope = 'Script'
        Name = 'IsWindows'
        Value = $true
        Option = 'ReadOnly'
    }
    Set-Variable @Parameters
}

# env:SHLVL + env:PSLVL
$PPID = (Get-Process -Id $PID).Parent.Id
if ($PPID) {
    $ParentProcessName = (Get-Process -Id $PPID -ErrorAction Ignore).ProcessName
    if ($ParentProcessName -match '(?i)^-?((pwsh(?:-preview)?|powershell)|bash|zsh|sh|csh|dash|ksh|tcsh).*$') {
        if ($null -ne $matches[2] ) {
            if($env:PSLVL) {
                $env:PSLVL = [int]$env:PSLVL + 1
            } else {
                $env:PSLVL = 1
            }
        }
        if($env:SHLVL) {
            $env:SHLVL = [int]$env:SHLVL + 1
        } else {
            $env:SHLVL = 1
        }
    } else {
        $env:SHLVL = 0
    }
}
else {
    $env:SHLVL = 0
}

$PROFILEHOME = Split-Path $PROFILE
$env:PSHOST_PROGRAM  = (Split-Path -Leaf $PROFILE.CurrentUserCurrentHost).Replace('Microsoft.','') -replace '_profile\.[^.]*$',''
$env:LC_PSHOST = $(
    if ($env:PSHOST_PROGRAM -eq 'PowerShell') {
        if ($IsCoreCLR) {
            'PowerShell'
        } else {
            'Windows PowerShell'
        }
    } else {
        (($env:PSHOST_PROGRAM -replace '(?-i)([a-z]{3,})([A-Z])','$1 $2') -replace '_',' ').Trim()
    }
)

if ($null -eq $env:PSLVL) {
    if ($IsWindows) {
        $PSType = if ($IsCoreCLR) { 'PowerShell' } else { 'WindowsPowerShell' }
        $PSMyDocumentsPath = [System.IO.Path]::Combine(([System.Environment]::GetFolderPath('MyDocuments')),$PSType)
        # $PSProgramFilesPath = [System.IO.Path]::Combine(([System.Environment]::GetFolderPath('ProgramFiles')),$PSType)

        $env:HOSTNAME        = $env:COMPUTERNAME
        $env:XDG_DATA_HOME   = [System.Environment]::GetFolderPath('LocalApplicationData')
        $env:XDG_CONFIG_HOME = [System.Environment]::GetFolderPath('ApplicationData')
        $env:XDG_STATE_HOME  = [System.IO.Path]::Combine($env:XDG_DATA_HOME,'State')
        $env:XDG_CACHE_HOME  = [System.IO.Path]::Combine($env:XDG_DATA_HOME,'Cache')

        $WindowsPrincipal = [Security.Principal.WindowsPrincipal]::new([Security.Principal.WindowsIdentity]::GetCurrent())
        if ($WindowsPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator) -eq 1) {
            $env:IsElevated = $true
        }

        if ($env:PSModulePath.Contains($env:OneDrive) -or $env:PSModulePath.Contains($env:OneDriveCommercial)) {
            $env:IsProfileRedirected = $true
        }
    }
    else {
        if ($env:SHLVL -eq 0) {
            if ($IsMacOS) {
                if (
                    -Not $IsLogin -and
                    ([System.IO.File]::Exists('/usr/libexec/path_helper'))
                ) {
                    function setenv ($n,$v) {[System.Environment]::SetEnvironmentVariable($n,$v)}
                    /usr/libexec/path_helper -c | Invoke-Expression -ErrorAction Ignore
                }

                # Homebrew support
                $(
                    if ([System.IO.File]::Exists('/opt/homebrew/bin/brew')) {
                        /opt/homebrew/bin/brew shellenv
                    }
                    elseif ([System.IO.File]::Exists('/usr/local/bin/brew')) {
                        /usr/local/bin/brew shellenv
                    }
                ) | Invoke-Expression -ErrorAction Ignore
            }
            else {
                # Homebrew on Linux support
                $(
                    if ([System.IO.File]::Exists("$HOME/.linuxbrew/bin/brew")) {
                        "$HOME/.linuxbrew/bin/brew shellenv"
                    }
                    elseif ([System.IO.File]::Exists('/home/linuxbrew/.linuxbrew/bin/brew')) {
                        '/home/linuxbrew/.linuxbrew/bin/brew shellenv'
                    }
                ) | Invoke-Expression -ErrorAction Ignore
            }
        }

        $PSMyDocumentsPath = [System.IO.Path]::Combine(([System.Environment]::GetFolderPath('LocalApplicationData')),'powershell')
        # $PSProgramFilesPath = '/usr/local/share/powershell'

        $env:PROCESSOR_ARCHITECTURE = $(uname -m).ToUpper() | ForEach-Object { if ($_ -eq 'X86_64') {'AMD64'} else {$_} }
        $env:COMPUTERNAME           = $(hostname -s).ToUpper()
        $env:HOSTNAME               = $env:COMPUTERNAME
        $env:XDG_DATA_HOME          = [System.IO.Path]::Combine(([System.Environment]::GetFolderPath('UserProfile')),'.local','share')
        $env:XDG_CONFIG_HOME        = [System.IO.Path]::Combine(([System.Environment]::GetFolderPath('UserProfile')),'.config')
        $env:XDG_STATE_HOME         = [System.IO.Path]::Combine(([System.Environment]::GetFolderPath('UserProfile')),'.local','state')
        $env:XDG_CACHE_HOME         = [System.IO.Path]::Combine(([System.Environment]::GetFolderPath('UserProfile')),'.cache')

        if (0 -eq (id -u)) {
            $env:IsElevated = $true
        }

        # env:PSModulePath
        $env:PSModulePath += [System.IO.Path]::PathSeparator + [System.IO.Path]::Combine($PROFILEHOME,'Modules')
    }

    # env:TERM_PROGRAM
    if (-Not $env:TERM_PROGRAM) {
        $TerminalName = $ParentProcessName -replace '(?:\(|Server)?(-.*)?$'
        if ($env:LC_TERMINAL) {
            $env:TERM_PROGRAM = $env:LC_TERMINAL
        }
        elseif (
            ($env:PSHOST_PROGRAM -ne 'PowerShell') -and
            ($env:PSHOST_PROGRAM -ne 'WindowsPowerShell')
        ) {
            $env:TERM_PROGRAM = $env:PSHOST_PROGRAM
        }
        elseif (
            $TerminalName -eq 'WindowsTerminal'
        ) {
            $env:TERM_PROGRAM = $TerminalName
        }
    }
    if ($env:TERM_PROGRAM -and -not $env:LC_TERMINAL) {
        $env:LC_TERMINAL = (($env:TERM_PROGRAM -replace '(?-i)([a-z]{3,})([A-Z])','$1 $2') -replace '_',' ').Trim()
    }

    # Add Scripts directories to env:PATH
    $p = [System.IO.Path]::Combine($PSMyDocumentsPath,'Scripts')
    if ([System.IO.Directory]::Exists($p)) {
        $env:PATH += [System.IO.Path]::PathSeparator + $p
    }
    if ($PSMyDocumentsPath -ne $PROFILEHOME) {
        $p = [System.IO.Path]::Combine($PROFILEHOME,'Scripts')
        if ([System.IO.Directory]::Exists($p)) {
            $env:PATH += [System.IO.Path]::PathSeparator + $p
        }
    }
}
#endregion

Get-PoProfileContent

$Exports = @{
    Variable = @(
        'IsCommand'
        'IsLogin'
        'IsNoExit'
        'IsNonInteractive'
        'IsCoreCLR'
        'IsLinux'
        'IsMacOS'
        'IsWindows'
        'PROFILEHOME'
        'PSStyle'
    )
}
Export-ModuleMember @Exports
