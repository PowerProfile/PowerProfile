@{
    ModuleName = 'PSReadline'
    MinimumVersion = '2.1'
    Commands = @{
        'Set-PSReadLineOption' = @{
            Colors = @{
                Selection = "$([char]27)[92;7m"
                InLinePrediction = "$([char]27)[36;7;238m"
            }
            PredictionSource = 'History'
        }
        'Set-PSReadLineKeyHandler' = @(
            @{
                Chord = 'Shift+Tab'
                Function = 'MenuComplete'
            }
            @{
                Chord = 'Ctrl+b'
                Function = 'BackwardWord'
            }
            @{
                Chord = 'Ctrl+f'
                Function = 'ForwardWord'
            }
            @{
                Chord = 'UpArrow'
                Function = 'HistorySearchBackward'
            }
            @{
                Chord = 'DownArrow'
                Function = 'HistorySearchForward'
            }
        )
    }
}
