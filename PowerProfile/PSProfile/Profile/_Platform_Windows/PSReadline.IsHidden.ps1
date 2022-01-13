if ((Get-Module PSReadLine).Version -ge '2.1' ) {
    Set-PSReadLineOption -Colors @{ Selection = "`e[92;7m"; InLinePrediction = "`e[36;7;238m" } -PredictionSource History
    Set-PSReadLineKeyHandler -Chord Shift+Tab -Function MenuComplete
    Set-PSReadLineKeyHandler -Chord Ctrl+b -Function BackwardWord
    Set-PSReadLineKeyHandler -Chord Ctrl+f -Function ForwardWord

    Set-PSReadLineOption -EditMode Emacs -ShowToolTips

    # Clipboard interaction is bound by default in Windows mode, but not Emacs mode.
    Set-PSReadLineKeyHandler -Key Ctrl+C -Function Copy
    Set-PSReadLineKeyHandler -Key Ctrl+v -Function Paste
}
