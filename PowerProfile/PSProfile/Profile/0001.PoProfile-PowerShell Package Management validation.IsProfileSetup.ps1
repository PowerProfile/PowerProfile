if (
    $null -eq (Get-PoProfileState 'PowerProfile.PSPackageManagement') -or
    ((Get-PoProfileState('PowerProfile.PSPackageManagement')).State -ne 'Complete')
) {
    if (Get-PoProfileState 'PowerProfile.PSPackageManagement') {
        $PSGetV2State = Get-PoProfileState 'PowerProfile.PSPackageManagement'
    } else {
        $PSGetV2State = @{ State = 'Incomplete' }
    }
    $PSGetV2State.LastUpdate = Get-Date

    if ((Get-ExecutionPolicy) -notmatch '(?i)^Bypass|Unrestricted|RemoteSigned$') {
        Write-PoProfileProgress -ScriptTitle "Setting PowerShell ExecutionPolicy to 'RemoteSigned'"
        Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
    }

    if ((Get-Module -ListAvailable -Name PowerShellGet).Version | Where-Object -Property Major -eq 3) {
        $PSGetV2State.State = 'Complete'
        Set-PoProfileState 'PowerProfile.PSPackageManagement' $PSGetV2State
        continue
    }

    if ((Get-PSRepository -Name PSGallery -ErrorAction Ignore).InstallationPolicy -eq 'Untrusted' ) {
        Write-PoProfileProgress -ScriptTitle "Setting InstallationPolicy for PSGallery to 'Trusted'"
        Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
    }

    $Cfg = Import-PowerShellDataFile -Path ((Get-PoProfileContent).PoProfileConfig.Profile.'PoProfile-PSPackageManagement.psd1')
    $InstalledPSGallery = Get-PSRepository -Name PSGallery -ErrorAction Ignore -WarningAction Ignore 2>$null
    $InstalledNuGetVersion = (Get-PackageProvider -ListAvailable -Name NuGet).Version
    $InstalledPMVersion = (Get-Module -ListAvailable -Name PackageManagement).Version
    $InstalledPSGetVersion = (Get-Module -ListAvailable -Name PowerShellGet).Version | Where-Object -Property Major -eq 2 | Sort-Object -Property Major,Minor,Build | Select-Object -Last 1

    if ($IsWindows -and $null -eq $env:IsElevated) {
        if (
            (-Not $InstalledPSGallery) -or
            ($InstalledNuGetVersion -lt $($Cfg.NuGetPackageProvider.MinimumVersion -replace '-[\w_.]+$')) -or
            ($InstalledPMVersion -lt $($Cfg.PackageManagement.MinimumVersion -replace '-[\w_.]+$')) -or
            ($InstalledPSGetVersion -lt $($Cfg.PowerShellGetV2.MinimumVersion -replace '-[\w_.]+$'))
        ) {
            Write-PoProfileProgress -ScriptTitleType Error -ScriptTitle 'Outdated PowerShell remote module installation capability detected.','Start an elevated PowerShell session for an automated fix.'
            continue
        } else {
            Write-PoProfileProgress -ScriptTitleType Confirmation -ScriptTitle 'System is up-to-date.'
            $PSGetV2State.State = 'Complete'
        }
    }

    # Auto-Update outdated PS package management
    #  before we can install and use state-of-the-art PS modules
    elseif (-Not $IsWindows -or ($IsWindows -and $null -ne $env:IsElevated)) {
        $MadeChanges = $false
        $Scope = if ($IsWindows) {'AllUsers'} else {'CurrentUser'}

        if ($InstalledNuGetVersion -lt $($Cfg.NuGetPackageProvider.MinimumVersion -replace '-[\w_.]+$')) {
            Write-PoProfileProgress -ScriptTitle 'Updating NuGet package provider' -InProgress
            try {
                Remove-Module PackageManagement
                $splatting = $Cfg.NuGetPackageProvider
                $null = Install-PackageProvider -Name NuGet -Scope $Scope -Force @splatting
                Remove-Module PackageManagement
            }
            catch {
                if ($null -eq $PSGetV2State.ErrorMessage) {
                    $PSGetV2State.ErrorMessage = @()
                }
                $PSGetV2State.ErrorMessage += 'Updating NuGet package provider: ' + $_.Exception.Message
                $PSGetV2State.State = 'Error'
            }
        }

        if ($null -eq $InstalledPSGallery) {
            try {
                Write-PoProfileProgress -ScriptTitle 'Registering PowerShell repository `PSGallery`'
                Register-PSRepository -Default
                Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
                $MadeChanges = $true
            }
            catch {
                if ($null -eq $PSGetV2State.ErrorMessage) {
                    $PSGetV2State.ErrorMessage = @()
                }
                $PSGetV2State.ErrorMessage += 'Registering PowerShell repository `PSGallery`: ' + $_.Exception.Message
                $PSGetV2State.State = 'Error'
            }
        }

        if ($InstalledPMVersion -lt $($Cfg.PackageManagement.MinimumVersion -replace '-[\w_.]+$')) {
            try {
                Write-PoProfileProgress -ScriptTitle 'Updating PackageManagement'
                Remove-Module PowerShellGet -Force -ErrorAction Ignore
                Remove-Module PackageManagement -Force -ErrorAction Ignore
                $splatting = $Cfg.PackageManagement
                $null = Install-Module -Name PackageManagement -Scope $Scope -Force -AllowClobber -Repository 'PSGallery' @splatting
                Remove-Module PowerShellGet -Force -ErrorAction Ignore
                Remove-Module PackageManagement -Force -ErrorAction Ignore
                $MadeChanges = $true
            }
            catch {
                if ($null -eq $PSGetV2State.ErrorMessage) {
                    $PSGetV2State.ErrorMessage = @()
                }
                $PSGetV2State.ErrorMessage += 'Updating PackageManagement: ' + $_.Exception.Message
                $PSGetV2State.State = 'Error'
            }
        }

        if ($InstalledPSGetVersion -lt $($Cfg.PowerShellGetV2.MinimumVersion -replace '-[\w_.]+$')) {
            try {
                Write-PoProfileProgress -ScriptTitle 'Updating PowerShellGet V2'
                Remove-Module PowerShellGet -Force -ErrorAction Ignore
                Remove-Module PackageManagement -Force -ErrorAction Ignore
                $splatting = $Cfg.PowerShellGetV2
                $null = Install-Module -Name PowerShellGet -Scope $Scope -Force -AllowClobber -Repository 'PSGallery' @splatting
                Remove-Module PowerShellGet -Force -ErrorAction Ignore
                Remove-Module PackageManagement -Force -ErrorAction Ignore
                $MadeChanges = $true
            }
            catch {
                if ($null -eq $PSGetV2State.ErrorMessage) {
                    $PSGetV2State.ErrorMessage = @()
                }
                $PSGetV2State.ErrorMessage += 'Updating PowerShellGet V2: ' + $_.Exception.Message
                $PSGetV2State.State = 'Error'
            }
        }

        if ($PSGetV2State.State -eq 'Error') {
            Write-PoProfileProgress -ScriptTitleType Error -ScriptTitle 'This setup step did not succeed.',('Run '+$PSStyle.Italic+'`Get-PoProfileState "PowerProfile.PSPackageManagement"`'+$PSStyle.ItalicOff+' for further details`')
        } else {
            if (-Not $MadeChanges) {
                Write-PoProfileProgress -ScriptTitleType Confirmation -ScriptTitle 'System is up-to-date.'
            }
            $PSGetV2State.State = 'Complete'
        }
    }

    Set-PoProfileState 'PowerProfile.PSPackageManagement' $PSGetV2State
}
