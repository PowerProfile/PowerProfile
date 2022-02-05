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
$buckets = scoop bucket list
$apps = $(scoop export) | Select-String '^(\S+) *(?:\(v:(\S+)\))? *(?:\[(\S+)\])?$' | ForEach-Object { $_.matches.groups[1].value }

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
        if (-Not $buckets.Contains($Bucket.BucketDetails.Name)) {
            scoop bucket add $Bucket.BucketDetails.Name
        }

        foreach ($App in $Bucket.Apps) {
            if (($null -eq $apps) -or -not $apps.Contains($App.Name)) {
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
