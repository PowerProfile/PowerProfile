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

$Settings = (Get-PoProfileContent).ConfigDirs.$CurrentProfile.'Homebrew'

if ($null -eq $Settings -or $Settings.Count -eq 0) {
    $SetupState.$ScriptFullName.State = 'Complete'
    continue ScriptNames
}

if (-Not (Get-Command brew -CommandType Application -ErrorAction Ignore)) {
    & "$PSScriptRoot/install-homebrew.sh"

    $(
        if (Test-Path -PathType Leaf /opt/homebrew/bin/brew) {
            /opt/homebrew/bin/brew shellenv
        }
        elseif (Test-Path -PathType Leaf /usr/local/bin/brew) {
            /usr/local/bin/brew shellenv
        }
    ) | Invoke-Expression -ErrorAction Ignore

    if (-Not (Get-Command brew -CommandType Application -ErrorAction Ignore)) {
        $SetupState.$ScriptFullName.State = 'FailedHomebrewSetup'
        continue ScriptNames
    }
}

[System.Collections.ArrayList]$Brewfiles = (Get-PoProfileContent).ConfigDirs.$CurrentProfile.Homebrew.keys

if ($Brewfiles.Count -gt 1 -and $Brewfiles -contains 'Brewfile') {
    $Brewfiles.Remove('Brewfile')
    $Brewfiles.Insert(0,'Brewfile')
}

$ExitCodeSum = 0

foreach ($Brewfile in $Brewfiles) {
    if ($Brewfile -notmatch '^(?:(.+)\.)?Brewfile$') {
        continue
    }

    if ($null -ne $Matches[1]) {
        Write-Host ('      ' + $Matches[1])
    }

    & "$PSScriptRoot/install-homebrew-package.sh" "$((Get-PoProfileContent).ConfigDirs.$CurrentProfile.Homebrew.$Brewfile)" | Out-Default
    if ($LASTEXITCODE -gt 0) {
        $ExitCodeSum += $LASTEXITCODE
    }
}

if ($ExitCodeSum -eq 0) {
    $SetupState.$ScriptFullName.State = 'Complete'
}
