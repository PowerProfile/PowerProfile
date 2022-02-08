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

$Settings = (Get-PoProfileContent).ConfigDirs.$CurrentProfile.'Scoop'

if ($null -eq $Settings -or $Settings.Count -eq 0) {
    $SetupState.$ScriptFullName.State = 'Complete'
    continue ScriptNames
}

if (-Not (Get-Command scoop -CommandType Application -ErrorAction Ignore)) {
    Invoke-WebRequest -Uri 'https://get.scoop.sh/' -TimeoutSec 5 | Invoke-Expression

    if (-Not (Get-Command scoop -CommandType Application -ErrorAction Ignore)) {
        $SetupState.$ScriptFullName.State = 'FailedScoopSetup'
        continue ScriptNames
    }
}

[System.Collections.ArrayList]$Scoopfiles = $Settings.keys

if ($Scoopfiles.Count -gt 1) {
    if ($Scoopfiles -contains 'PoProfile.Scoop.psd1') {
        $Scoopfiles.Remove('PoProfile.Scoop.psd1')
        $Scoopfiles.Insert(0,'PoProfile.Scoop.psd1')
    }
    if ($Scoopfiles -contains 'PoProfile.Scoop.json') {
        $Scoopfiles.Remove('PoProfile.Scoop.json')
        $Scoopfiles.Insert(0,'PoProfile.Scoop.json')
    }
}

$ExitCodeSum = 0
$Buckets = scoop bucket list
$Apps = $(scoop export) | Select-String '^(\S+) *(?:\(v:(\S+)\))? *(?:\[(\S+)\])?$' | ForEach-Object { $_.matches.groups[1].value }

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

    foreach ($Bucket in $Cfg.Buckets) {
        if (-Not $Buckets.Contains($Bucket.BucketDetails.Name)) {
            scoop bucket add $Bucket.BucketDetails.Name
        }

        foreach ($App in $Bucket.Apps) {
            if (($null -eq $Apps) -or -not $Apps.Contains($App.Name)) {
                Write-Host ('      ' + $App.Name)
                scoop install $App.Name
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
