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
            $LastCmdDuration = New-TimeSpan -Start $LastCmd.StartExecutionTime -End $LastCmd.EndExecutionTime
            $CmdDur = $LastCmdDuration.TotalMilliseconds
            $u = 'ms'
            if ($CmdDur -gt 250 -and $CmdDur -lt 1000) {
                $DurColor = $PSStyle.Foreground.Yellow
            } elseif ($CmdDur -ge 1000) {
                $DurColor = $PSStyle.Foreground.Red
                if ($CmdDur -ge 60000) {
                    $CmdDur = $LastCmdDuration.TotalMinutes
                    $u = 'm'
                } else {
                    $CmdDur = $LastCmdDuration.TotalSeconds
                    $u = 's'
                }
            }
            $Runtime = "$($PSStyle.Foreground.BrightBlack)[$DurColor$($CmdDur.ToString('#.##'))$u$($PSStyle.Foreground.BrightBlack)]$($PSStyle.Reset) "
        }

        $Path = $executionContext.SessionState.Path.CurrentLocation.Path -replace [regex]::Escape($HOME),'~'
        $MaxLength = [int](([Console]::WindowWidth) / 2)
        if ($Path.Length -gt $MaxLength) {
            $Path = $PSStyle.Foreground.BrightBlack + $PoProfileChar.GeneralPunctuation.horizontal_ellipsis + $PSStyle.Foreground.Reset + $Path.SubString($Path.Length - $MaxLength)
        }

        "${Runtime}${Path}`n$(if(0 -lt $env:SHLVL){"$($PSStyle.Foreground.BrightBlack)($env:SHLVL) "}else{''})${PromptExit}PS$(if($env:IsElevated){' ' + $PSStyle.Foreground.BrightRed + $PoProfileChar.GeneralPunctuation.double_exclamation_mark + $PSStyle.Reset}else{$PSStyle.Reset})$('>' * ($nestedPromptLevel + 1)) ";

        try {
            if ($IsWindows) {
                $Path = "$env:COMPUTERNAME" + ':' + $($executionContext.SessionState.Path.CurrentLocation.Path -replace [regex]::Escape($HOME),'~')
                $host.UI.RawUI.WindowTitle = $(if ($env:IsElevated) {'Admin: ' + $Path} else {$Path})
            } else {
                $host.UI.RawUI.WindowTitle = "$env:USER@$env:HOSTNAME" + ':' + $($PWD.Path -replace [regex]::Escape($HOME),'~')
            }
        }
        catch {
            # nothing to do
        }
    }

    $global:LASTEXITCODE = $PromptLASTEXITCODE
}
