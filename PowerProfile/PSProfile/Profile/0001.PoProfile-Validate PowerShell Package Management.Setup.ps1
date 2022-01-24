if ((Get-ExecutionPolicy) -notmatch '(?i)^Bypass|Unrestricted|RemoteSigned$') {
    Write-PoProfileProgress -ScriptTitle "Setting PowerShell ExecutionPolicy to 'RemoteSigned'"
    Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
}

if ((Get-Module -ListAvailable -Name PowerShellGet).Version | Where-Object -Property Major -eq 3) {
    $SetupState.$ScriptFullName.State = 'Complete'
    continue ScriptNames
}

if ((Get-PSRepository -Name PSGallery -ErrorAction Ignore).InstallationPolicy -eq 'Untrusted' ) {
    Write-PoProfileProgress -ScriptTitle "Setting InstallationPolicy for PSGallery to 'Trusted'"
    Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
}

$Cfg = Import-PowerShellDataFile -Path ((Get-PoProfileContent).Config.Profile.'PoProfile-PSPackageManagement.config.psd1')
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
        $SetupState.$ScriptFullName.State = 'PendingElevation'
        continue ScriptNames
    } else {
        Write-PoProfileProgress -ScriptTitleType Confirmation -ScriptTitle 'System is up-to-date.'
        $SetupState.$ScriptFullName.State = 'Complete'
        continue ScriptNames
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
            $SetupState.$ScriptFullName.ErrorMessage += 'Updating NuGet package provider: ' + $_.Exception.Message
            $SetupState.$ScriptFullName.State = 'Error'
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
            $SetupState.$ScriptFullName.ErrorMessage += 'Registering PowerShell repository `PSGallery`: ' + $_.Exception.Message
            $SetupState.$ScriptFullName.State = 'Error'
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
            $SetupState.$ScriptFullName.ErrorMessage += 'Updating PackageManagement: ' + $_.Exception.Message
            $SetupState.$ScriptFullName.State = 'Error'
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
            $SetupState.$ScriptFullName.ErrorMessage += 'Updating PowerShellGet V2: ' + $_.Exception.Message
            $SetupState.$ScriptFullName.State = 'Error'
        }
    }

    if ($SetupState.$ScriptFullName.State -ne 'Error') {
        if (-Not $MadeChanges) {
            Write-PoProfileProgress -ScriptTitleType Confirmation -ScriptTitle 'System is up-to-date.'
        }
        $SetupState.$ScriptFullName.State = 'Complete'
    }
}
