$Settings = (Get-PoProfileContent).ConfigDirs.$CurrentProfile.'Winget'

if ($null -eq $Settings -or $Settings.Count -eq 0) {
    $SetupState.$ScriptFullName.State = 'Complete'
    continue ScriptNames
}

if (-Not (Get-Command winget -CommandType Application -ErrorAction Ignore)) {
    Start-Job -Name WingetInstall -ScriptBlock { Add-AppxPackage -Path https://aka.ms/getwinget -ErrorAction Ignore }
    Wait-Job -Name WingetInstall

    if (-Not (Get-Command winget -CommandType Application -ErrorAction Ignore)) {
        $SetupState.$ScriptFullName.State = 'FailedWingetSetup'
        continue ScriptNames
    }
}

[System.Collections.ArrayList]$Wingetfiles = $Settings.keys

if ($Wingetfiles.Count -gt 1) {
    if ($Wingetfiles -contains 'PoProfile.Winget.psd1') {
        $Wingetfiles.Remove('PoProfile.Winget.psd1')
        $Wingetfiles.Insert(0,'PoProfile.Winget.psd1')
    }
    if ($Wingetfiles -contains 'PoProfile.Winget.json') {
        $Wingetfiles.Remove('PoProfile.Winget.json')
        $Wingetfiles.Insert(0,'PoProfile.Winget.json')
    }
}

$ExitCodeSum = 0

foreach ($Wingetfile in $Wingetfiles) {
    if ($Wingetfile -match '\.Winget\.json$') {
        try {
            $Cfg = ConvertFrom-Json -InputObject ([System.IO.File]::ReadAllText($Settings.$Wingetfile))
        }
        catch {
            continue
        }
    } else {
        continue
    }

    # we can't use the winget import command as it will not detect apps that are already installed
    foreach ($Source in $Cfg.Sources) {
        foreach ($Package in $Source.Packages) {
            $listApp = winget list --exact --source $Source.SourceDetails.Name -q $Package.PackageIdentifier
            if (-Not [String]::Join("", $listApp).Contains($Package.PackageIdentifier)) {
                Write-Host ('      ' + $Package.PackageIdentifier)
                winget install --exact $Package.PackageIdentifier --source $Source.SourceDetails.Name --accept-source-agreements --accept-package-agreements
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
