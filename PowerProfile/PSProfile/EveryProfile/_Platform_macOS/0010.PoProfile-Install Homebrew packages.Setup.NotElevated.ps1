<#
.SYNOPSIS
    macOS Homebrew and software installation

.DESCRIPTION
    macOS Homebrew and software installation

.LINK
    https://github.com/PowerProfile/psprofile-common
#>

$HasHomebrew = $false

if (Get-Command brew -CommandType Application -ErrorAction Ignore) {
    $HasHomebrew = $true
} else {
    & "$PSScriptRoot/install-homebrew.sh"

    $(
        if (Test-Path -PathType Leaf /opt/homebrew/bin/brew) {
            /opt/homebrew/bin/brew shellenv
        }
        elseif (Test-Path -PathType Leaf /usr/local/bin/brew) {
            /usr/local/bin/brew shellenv
        }
    ) | Invoke-Expression -ErrorAction Ignore

    if (Get-Command brew -CommandType Application -ErrorAction Ignore) {
        $HasHomebrew = $true
    }
}

if ($HasHomebrew) {
    [System.Collections.ArrayList]$Brewfiles = (Get-PoProfileContent).ConfigDirs.$CurrentProfile.Homebrew.keys

    if ($Brewfiles -contains 'Brewfile') {
        $Brewfiles.Remove('Brewfile')
        $Brewfiles.Insert(0,'Brewfile')
    }
    $ExitCodeSum = 0
    foreach ($Brewfile in $Brewfiles) {
        if ($Brewfile -notmatch 'Brewfile$') {
            continue
        }

        & "$PSScriptRoot/install-homebrew-packages.sh" "$((Get-PoProfileContent).ConfigDirs.$CurrentProfile.Homebrew.$Brewfile)" | Out-Default
        if ($LASTEXITCODE -gt 0) {
            $ExitCodeSum += $LASTEXITCODE
        }
    }

    if ($ExitCodeSum -eq 0) {
        $SetupState.$ScriptFullName.State = 'Complete'
    }
}
