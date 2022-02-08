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

$Settings = (Get-PoProfileContent).ConfigDirs.$CurrentProfile.'Chocolatey'

if ($null -eq $Settings -or $Settings.Count -eq 0) {
    $SetupState.$ScriptFullName.State = 'Complete'
    continue ScriptNames
}

if (-Not (Get-Command choco -CommandType Application -ErrorAction Ignore)) {
    if ($CanElevate -or $IsElevated) {
        $cmd = Start-Process -Verb RunAs -PassThru -Wait -FilePath $env:SHELL -ArgumentList @(
            '--NoProfile'
            '--Command'
            "Invoke-WebRequest -Uri 'https://community.chocolatey.org/install.ps1' -TimeoutSec 5 | Invoke-Expression"
        )
    } else {
        $InstallDir             = 'C:\ProgramData\chocoportable'
        $env:ChocolateyInstall  = "$InstallDir"
        Set-ExecutionPolicy Bypass -Scope Process -Force
        Invoke-WebRequest -Uri 'https://community.chocolatey.org/install.ps1' -TimeoutSec 5 | Invoke-Expression
    }

    if (-Not (Get-Command choco -CommandType Application -ErrorAction Ignore)) {
        $SetupState.$ScriptFullName.State = 'FailedChocolateySetup'
        continue ScriptNames
    }
}

[System.Collections.ArrayList]$Chocofiles = $Settings.keys

if ($Chocofiles.Count -gt 1) {
    if ($Chocofiles -contains 'PoProfile.Choco.psd1') {
        $Chocofiles.Remove('PoProfile.Choco.psd1')
        $Chocofiles.Insert(0,'PoProfile.Choco.psd1')
    }
    if ($Chocofiles -contains 'PoProfile.Choco.json') {
        $Chocofiles.Remove('PoProfile.Choco.json')
        $Chocofiles.Insert(0,'PoProfile.Choco.json')
    }
}

$ExitCodeSum = 0
$Sources = choco sources --no-color
$Packages = choco list --local --no-color

foreach ($Scoopfile in $Scoopfiles) {
    if ($Scoopfile -match '\.Scoop\.json$') {
        try {
            $Cfg = ConvertFrom-Json -InputObject ([System.IO.File]::ReadAllText($Settings.$Scoopfile))
        }
        catch {
            continue
        }
    } else {
        continue
    }

    foreach ($Source in $Cfg.Sources) {
        if (-Not $Sources.Contains($Source.SourceDetails.Name)) {
            choco source add $Source.SourceDetails.Name
        }

        foreach ($Package in $Source.Packages) {
            if (($null -eq $Packages) -or -not $Packages.Contains($Package.Name)) {
                Write-Host ('      ' + $Package.Name)
                choco install $Package.Name
                if ($LASTEXITCODE -gt 0) {
                    $ExitCodeSum += $LASTEXITCODE
                }
            }
        }
    }
}

if ($ExitCodeSum -eq 0) {
    $SetupState.$ScriptFullName.State = 'Complete'
}
