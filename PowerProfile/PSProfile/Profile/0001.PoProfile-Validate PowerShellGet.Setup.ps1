if ($SetupState.'0001.PoProfile-Validate PowerShell Package Management.Setup.ps1'.State -ne 'Complete') {
    $SetupState.$ScriptFullName.State = 'PendingPackageManagementSetup'
    Continue ScriptNames
}

Remove-Module PowerShellGet -Force -ErrorAction Ignore
Remove-Module PackageManagement -Force -ErrorAction Ignore

$Cfg = Import-PowerShellDataFile -Path ((Get-PoProfileContent).Config.Profile.'PoProfile-PSPowerShellGet.config.psd1')
$InstalledPSGetVersion = (Get-Module -ListAvailable -Name PowerShellGet).Version | Where-Object -Property Major -eq 3 | Sort-Object -Property Major,Minor,Build | Select-Object -Last 1

if ($IsWindows -and $null -eq $env:IsElevated) {
    if (
        ($InstalledPSGetVersion -lt $($Cfg.PowerShellGet.Version -replace '-[\w_.]+$'))
    ) {
        Write-PoProfileProgress -ScriptTitleType Error -ScriptTitle 'Outdated PowerShellGet version detected.','Start an elevated PowerShell session for an automated fix.'
        $SetupState.$ScriptFullName.State = 'PendingElevation'
        continue ScriptNames
    } else {
        Write-PoProfileProgress -ScriptTitleType Confirmation -ScriptTitle 'PowerShellGet is up-to-date.'
        $SetupState.$ScriptFullName.State = 'Complete'
    }
}

# Auto-Update outdated PowerShellGet
#  before we can install and use state-of-the-art PS modules
elseif (-Not $IsWindows -or ($IsWindows -and $null -ne $env:IsElevated)) {
    $MadeChanges = $false
    $Scope = if ($IsWindows) {'AllUsers'} else {'CurrentUser'}

    if ($null -eq $InstalledPSGetVersion) {
        try {
            Write-PoProfileProgress -ScriptTitle 'Upgrading PowerShellGet V2 to V3'
            Remove-Module PowerShellGet -Force -ErrorAction Ignore
            Remove-Module PackageManagement -Force -ErrorAction Ignore
            $splatting = $Cfg.PowerShellGetV2toV3
            Install-Module -Name PowerShellGet -Scope $Scope -Force -AllowClobber -Repository PSGallery -SkipPublisherCheck @splatting
            Remove-Module PowerShellGet -Force -ErrorAction Ignore
            Remove-Module PackageManagement -Force -ErrorAction Ignore
            Install-PSResource -Name CompatPowerShellGet -Scope $Scope -Repository PSGallery -TrustRepository -Reinstall
            $MadeChanges = $true
        }
        catch {
            $SetupState.$ScriptFullName.ErrorMessage += 'Upgrading PowerShellGet V2 to V3: ' + $_.Exception.Message
            $SetupState.$ScriptFullName.State = 'Error'
        }
    }
    elseif ($InstalledPSGetVersion -lt $($Cfg.PowerShellGet.Version -replace '-[\w_.]+$')) {
        try {
            Write-PoProfileProgress -ScriptTitle 'Updating PowerShellGet'
            Remove-Module PowerShellGet -Force -ErrorAction Ignore
            Remove-Module PackageManagement -Force -ErrorAction Ignore
            $splatting = $Cfg.PowerShellGet
            Install-PSResource -Name PowerShellGet -Scope $Scope -Repository PSGallery -TrustRepository @splatting
            Remove-Module PowerShellGet -Force -ErrorAction Ignore
            Remove-Module PackageManagement -Force -ErrorAction Ignore
            Install-PSResource -Name CompatPowerShellGet -Scope $Scope -Repository PSGallery -TrustRepository -Reinstall
            $MadeChanges = $true
        }
        catch {
            $SetupState.$ScriptFullName.ErrorMessage += 'Updating PowerShellGet: ' + $_.Exception.Message
            $SetupState.$ScriptFullName.State = 'Error'
        }
    }

    if ($null -ne $Cfg.PSResourceRepository) {
        foreach ($Repo in $Cfg.PSResourceRepository) {
            try {
                if (Get-PSResourceRepository -Name $Repo.Name -ErrorAction Ignore) {
                    Write-PoProfileProgress -ScriptTitle ('Updating source repository ' + $PSStyle.Italic + $Repo.Name + $PSStyle.ItalicOff)
                    Set-PSResourceRepository @Repo
                } else {
                    Write-PoProfileProgress -ScriptTitle ('Registering source repository ' + $PSStyle.Italic + $Repo.Name + $PSStyle.ItalicOff)
                    Register-PSResourceRepository @Repo
                }
            }
            catch {
                $SetupState.$ScriptFullName.ErrorMessage += 'PSResourceRepository '+$Repo.Name+': ' + $_.Exception.Message
                $SetupState.$ScriptFullName.State = 'Error'
            }
        }
    }

    if ($SetupState.$ScriptFullName.State -ne 'Error') {
        if (-Not $MadeChanges) {
            Write-PoProfileProgress -ScriptTitleType Confirmation -ScriptTitle 'PowerShellGet is up-to-date.'
        }
        $SetupState.$ScriptFullName.State = 'Complete'
    }
}
