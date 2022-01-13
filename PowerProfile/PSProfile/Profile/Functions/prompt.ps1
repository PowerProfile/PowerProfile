function prompt {
    $PromptSuccess = $?
    $PromptLASTEXITCODE = $global:LASTEXITCODE

    if ($IsNonInteractive) {
        "PS $($executionContext.SessionState.Path.CurrentLocation)$('>' * ($nestedPromptLevel + 1)) ";
    }
    else {
        if ($PromptSuccess -eq $false) {
            $PromptExit = $PSStyle.Foreground.BrightRed
        } else {
            $PromptExit = $PSStyle.Foreground.BrightGreen
        }

        $Runtime = ''
        $LastCmd = Get-History -Count 1
        if ($null -ne $LastCmd) {
            $DurColor = $PSStyle.Foreground.Green
            $CmdDur = $LastCmd.Duration.TotalMilliseconds
            $u = 'ms'
            if ($CmdDur -gt 250 -and $CmdDur -lt 1000) {
                $DurColor = $PSStyle.Foreground.Yellow
            } elseif ($CmdDur -ge 1000) {
                $DurColor = $PSStyle.Foreground.Red
                if ($CmdDur -ge 60000) {
                    $CmdDur = $LastCmd.Duration.TotalMinutes
                    $u = 'm'
                } else {
                    $CmdDur = $LastCmd.Duration.TotalSeconds
                    $u = 's'
                }
            }
            $Runtime = "$($PSStyle.Foreground.BrightBlack)[$DurColor$($CmdDur.ToString('#.##'))$u$($PSStyle.Foreground.BrightBlack)]$($PSStyle.Reset) "
        }

        $Path = $executionContext.SessionState.Path.CurrentLocation.Path
        $MaxLength = [int](([Console]::WindowWidth) / 2)
        if ($Path.Length -gt $MaxLength) {
            $Path = '…' + $Path.SubString($Path.Length - $MaxLength)
        }

        "${Runtime}${Path}`n$(if(0 -lt $env:SHLVL){"$($PSStyle.Foreground.BrightBlack)($env:SHLVL) "}else{''})${PromptExit}PS$(if($env:IsElevated){" $($PSStyle.Foreground.BrightRed)‼$($PSStyle.Reset)"}else{$PSStyle.Reset})$('>' * ($nestedPromptLevel + 1)) ";

        try {
            $Path = "$env:USER@$env:COMPUTERNAME" + ':' + $($PWD.Path -replace $HOME,'~')
            $Host.UI.RawUI.WindowTitle = if ($env:IsElevated -and $IsWindows) {'Admin: ' + $Path} else {$Path}
        }
        catch {
            # nothing to do
        }
    }

    $global:LASTEXITCODE = $PromptLASTEXITCODE
}
