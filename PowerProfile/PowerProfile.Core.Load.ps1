#Requires -Version 5.1
if ($PSVersionTable.PSVersion.Major -eq 6) {
    throw 'PowerProfile requires PowerShell Core version 7.0 or higher'
}

#region Preparation
$env:PSExecutionPolicyPreference = 'RemoteSigned'
$PoProfileOriginScriptPath = (Get-PSCallStack)[1].InvocationInfo.MyCommand.Path      # [...]\Documents\PowerShell\profile.ps1
if ($null -ne $PoProfileOriginScriptPath) {
    $PoProfileModulePath = [System.IO.Path]::Combine(                                # [...]\Documents\PowerShell\Modules
                    (Split-Path $PoProfileOriginScriptPath),
                    'Modules'
                )
}
elseif ($PSEdition -eq 'Desktop' -or $IsWindows) {
    Get-ChildItem -File -Recurse -FollowSymlink -Path $PSScriptRoot | ForEach-Object { Unblock-File -Path $_.FullName -ErrorAction Ignore -Confirm:$false -WhatIf:$false }
}

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

Import-Module -Force -DisableNameChecking -Name ([System.IO.Path]::Combine($PSScriptRoot,'PowerProfile.Core.psd1')) -ErrorAction Stop
#endregion

#region Setup
if ($null -eq $PoProfileOriginScriptPath) {
    Write-PoProfileProgress -ProfileTitle "`nPowerProfile Initialization"

    $PoProfileModulePath = Join-Path (Split-Path $PROFILE.CurrentUserAllHosts) 'Modules'
    $datetime = (Get-Date).ToString('yyyy-MM-dd_HHmmss')

    if ($PSScriptRoot -notmatch "^$([regex]::Escape($PoProfileModulePath))") {
        $null = New-Item -ItemType Directory -Force -Path $PoProfileModulePath -ErrorAction Ignore
        Write-PoProfileProgress -ScriptTitleType Error -ScriptTitle @(
            'ERROR:'
            ('Move the '+'`'+"$($PSStyle.Italic)PowerProfile$($PSStyle.ItalicOff)"+'`'+' folder '+" from $($PSStyle.FormatHyperlink('here','file://'+(Split-Path $PSScriptRoot))) to profile folder $($PSStyle.FormatHyperlink($PoProfileModulePath,'file://'+$PoProfileModulePath)) first.")
        )
        Remove-Module -Force PowerProfile.Core -ErrorAction Ignore
        $env:PSExecutionPolicyPreference = $null
        throw
    }

    if (Test-Path $PROFILE.CurrentUserCurrentHost) {
        $bak = $PROFILE.CurrentUserCurrentHost + '.bak.' + $datetime
        Rename-Item $PROFILE.CurrentUserCurrentHost $bak
        Write-PoProfileProgress -ScriptTitleType Information -ScriptTitle @(
            ($PSStyle.Italic + (Split-Path -Leaf $PROFILE.CurrentUserCurrentHost) + $PSStyle.ItalicOff + ' backed up:')
            "The existing file was renamed to $($PSStyle.FormatHyperlink((Split-Path -Leaf $bak),'file://'+(Split-Path $bak)))"
            'for further investigation.'
        )
    }

    if (Test-Path $PROFILE.CurrentUserAllHosts) {
        if (
            (Get-FileHash -Path (Join-Path $PSScriptRoot 'profile.ps1')).Hash -ne
            (Get-FileHash -Path $PROFILE.CurrentUserAllHosts).Hash
        ) {
            $bak = $PROFILE.CurrentUserAllHosts + '.bak.' + $datetime
            Rename-Item $PROFILE.CurrentUserAllHosts $bak

            Write-PoProfileProgress -ScriptTitleType Information -ScriptTitle @(
                ($PSStyle.Italic + (Split-Path -Leaf $PROFILE.CurrentUserAllHosts) + $PSStyle.ItalicOff + ' backed up:')
                "The existing file was renamed to $($PSStyle.FormatHyperlink((Split-Path -Leaf $bak),'file://'+(Split-Path $bak)))"
                'for further investigation.'
            )

            Copy-Item (Join-Path $PSScriptRoot 'profile.ps1') $PROFILE.CurrentUserAllHosts
            $SetupCompleted = $true
        }
    } else {
        Copy-Item (Join-Path $PSScriptRoot 'profile.ps1') $PROFILE.CurrentUserAllHosts
        $SetupCompleted = $true
    }

    if ($SetupCompleted) {
        Remove-Variable -Name 'SetupCompleted'

        Write-PoProfileProgress -ScriptTitleType Confirmation -ScriptTitle 'PowerProfile Setup COMPLETED !'
        Write-PoProfileProgress -ScriptTitleType Note -NoCounter -ScriptTitle ('Use the '+'`'+"$($PSStyle.Italic)New-PowerProfile$($PSStyle.ItalicOff)"+'`'+' command to create profile directories.')
        Write-PoProfileProgress -ScriptTitleType Note -NoCounter -ScriptTitle ('Type '+'`'+"$($PSStyle.Italic)help PowerProfile$($PSStyle.ItalicOff)"+'`'+' for more details,')
        Write-PoProfileProgress -ScriptTitleType Note -NoCounter -ScriptTitle ("or visit $($PSStyle.FormatHyperlink('the PowerProfile website','https://PowerProfile.sh/')) to learn more about PowerProfile.")
    }
}
#endregion

#region Preloading checks
elseif ($PSScriptRoot -notmatch "^$([regex]::Escape($PoProfileModulePath))") {
    Write-PoProfileProgress -ProfileTitle "PowerProfile Error" -ScriptTitleType Error -ScriptTitle @(
        'The PowerProfile module is not saved as part of your profile.'
        "Make sure the module files are moved back into $($PSStyle.FormatHyperlink('this Modules folder','file://'+$PoProfileModulePath))."
    )
    Remove-Module -Force PowerProfile.Core -ErrorAction Ignore
    $env:PSExecutionPolicyPreference = $null
    throw
}
elseif ($PoProfileOriginScriptPath -ne $PROFILE.CurrentUserAllHosts) {
    Remove-Module -Force PowerProfile.Core -ErrorAction Ignore
    $env:PSExecutionPolicyPreference = $null
    throw 'PowerProfile can not be imported into other PowerShell scripts or modules'
}
#endregion

Remove-Variable -Name 'PoProfileOriginScriptPath','PoProfileModulePath'

# SIG # Begin signature block
# MIIjcwYJKoZIhvcNAQcCoIIjZDCCI2ACAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUntlpHIyQISrWOhasbSl2DcQE
# 92Gggh5CMIIEsjCCAxqgAwIBAgIQZPBZ/lp+1ePchI7H9oB7ajANBgkqhkiG9w0B
# AQwFADBUMQswCQYDVQQGEwJHQjEYMBYGA1UEChMPU2VjdGlnbyBMaW1pdGVkMSsw
# KQYDVQQDEyJTZWN0aWdvIFB1YmxpYyBDb2RlIFNpZ25pbmcgQ0EgUjM2MB4XDTIy
# MDIwMTAwMDAwMFoXDTIzMDIwMTIzNTk1OVowYTELMAkGA1UEBhMCREUxEDAOBgNV
# BAgMB0hhbWJ1cmcxHzAdBgNVBAoMFkp1bGlhbiBFcmljaCBQYXdsb3dza2kxHzAd
# BgNVBAMMFkp1bGlhbiBFcmljaCBQYXdsb3dza2kwWTATBgcqhkjOPQIBBggqhkjO
# PQMBBwNCAAT7wGa6gymFpwwr4NM1OP+ytZ42PCXg2k/QClUMXomet5hf3sTqV6S0
# /B5EF+IwLortN7YKf6JqdcilFGBXm0qwo4IBvDCCAbgwHwYDVR0jBBgwFoAUDyrL
# IIcouOxvSK4rVKYpqhekzQwwHQYDVR0OBBYEFKgzc5pykfW25dLBJ36bTK1C20DB
# MA4GA1UdDwEB/wQEAwIHgDAMBgNVHRMBAf8EAjAAMBMGA1UdJQQMMAoGCCsGAQUF
# BwMDMBEGCWCGSAGG+EIBAQQEAwIEEDBKBgNVHSAEQzBBMDUGDCsGAQQBsjEBAgED
# AjAlMCMGCCsGAQUFBwIBFhdodHRwczovL3NlY3RpZ28uY29tL0NQUzAIBgZngQwB
# BAEwSQYDVR0fBEIwQDA+oDygOoY4aHR0cDovL2NybC5zZWN0aWdvLmNvbS9TZWN0
# aWdvUHVibGljQ29kZVNpZ25pbmdDQVIzNi5jcmwweQYIKwYBBQUHAQEEbTBrMEQG
# CCsGAQUFBzAChjhodHRwOi8vY3J0LnNlY3RpZ28uY29tL1NlY3RpZ29QdWJsaWND
# b2RlU2lnbmluZ0NBUjM2LmNydDAjBggrBgEFBQcwAYYXaHR0cDovL29jc3Auc2Vj
# dGlnby5jb20wHgYDVR0RBBcwFYETanVsaWFuQHBhd2xvd3NraS5tZTANBgkqhkiG
# 9w0BAQwFAAOCAYEAdaqtNfp8s8YE5PXoq3RZ8f3yQwh9y6cYFkDQAIXxdyk5XHYK
# EM+EEcj+KS8yzla39lcZXumP/XLPvu18CZT+MG3hp73TbWdO3wsnj2X0440I4n0M
# bbJuCJ6POKB+moLk8Sbr6Hbkj1zUMfOh74CRo6qlzpqBJjbxhdTuBwE2WcPiQocL
# zKFCZ1xenommZ8sioqgaW/OgESm7CF8YMPxULucfg4mpZijoqL+GgEnWQqvh3uoP
# fLx0rWr8Q36TARWr1roAIXTBDbLAaXLkVQ20cID0t8h4R0ZYZCytT+bx28zARAQl
# r6DQZKhm8R+waqpz/O0tUQ33pSz+fn6uYwMW6IDVslU6pLkWDWrwAPCVOmQ7AyRe
# mov45XAaqR2z58uoVdnm7JzyWVEe/ijKD1LjNrbtztmqAPQ9vdQWyhGlbFtdysMQ
# xSGDH8YkQ575QacHlHr5F2u8QgmDfsgxui7Ol/SqPR+DxnGVbkM3zSBdet4PQ9+B
# OTIDmrWKYFNQWlvCMIIFbzCCBFegAwIBAgIQSPyTtGBVlI02p8mKidaUFjANBgkq
# hkiG9w0BAQwFADB7MQswCQYDVQQGEwJHQjEbMBkGA1UECAwSR3JlYXRlciBNYW5j
# aGVzdGVyMRAwDgYDVQQHDAdTYWxmb3JkMRowGAYDVQQKDBFDb21vZG8gQ0EgTGlt
# aXRlZDEhMB8GA1UEAwwYQUFBIENlcnRpZmljYXRlIFNlcnZpY2VzMB4XDTIxMDUy
# NTAwMDAwMFoXDTI4MTIzMTIzNTk1OVowVjELMAkGA1UEBhMCR0IxGDAWBgNVBAoT
# D1NlY3RpZ28gTGltaXRlZDEtMCsGA1UEAxMkU2VjdGlnbyBQdWJsaWMgQ29kZSBT
# aWduaW5nIFJvb3QgUjQ2MIICIjANBgkqhkiG9w0BAQEFAAOCAg8AMIICCgKCAgEA
# jeeUEiIEJHQu/xYjApKKtq42haxH1CORKz7cfeIxoFFvrISR41KKteKW3tCHYySJ
# iv/vEpM7fbu2ir29BX8nm2tl06UMabG8STma8W1uquSggyfamg0rUOlLW7O4ZDak
# fko9qXGrYbNzszwLDO/bM1flvjQ345cbXf0fEj2CA3bm+z9m0pQxafptszSswXp4
# 3JJQ8mTHqi0Eq8Nq6uAvp6fcbtfo/9ohq0C/ue4NnsbZnpnvxt4fqQx2sycgoda6
# /YDnAdLv64IplXCN/7sVz/7RDzaiLk8ykHRGa0c1E3cFM09jLrgt4b9lpwRrGNhx
# +swI8m2JmRCxrds+LOSqGLDGBwF1Z95t6WNjHjZ/aYm+qkU+blpfj6Fby50whjDo
# A7NAxg0POM1nqFOI+rgwZfpvx+cdsYN0aT6sxGg7seZnM5q2COCABUhA7vaCZEao
# 9XOwBpXybGWfv1VbHJxXGsd4RnxwqpQbghesh+m2yQ6BHEDWFhcp/FycGCvqRfXv
# vdVnTyheBe6QTHrnxvTQ/PrNPjJGEyA2igTqt6oHRpwNkzoJZplYXCmjuQymMDg8
# 0EY2NXycuu7D1fkKdvp+BRtAypI16dV60bV/AK6pkKrFfwGcELEW/MxuGNxvYv6m
# UKe4e7idFT/+IAx1yCJaE5UZkADpGtXChvHjjuxf9OUCAwEAAaOCARIwggEOMB8G
# A1UdIwQYMBaAFKARCiM+lvEH7OKvKe+CpX/QMKS0MB0GA1UdDgQWBBQy65Ka/zWW
# SC8oQEJwIDaRXBeF5jAOBgNVHQ8BAf8EBAMCAYYwDwYDVR0TAQH/BAUwAwEB/zAT
# BgNVHSUEDDAKBggrBgEFBQcDAzAbBgNVHSAEFDASMAYGBFUdIAAwCAYGZ4EMAQQB
# MEMGA1UdHwQ8MDowOKA2oDSGMmh0dHA6Ly9jcmwuY29tb2RvY2EuY29tL0FBQUNl
# cnRpZmljYXRlU2VydmljZXMuY3JsMDQGCCsGAQUFBwEBBCgwJjAkBggrBgEFBQcw
# AYYYaHR0cDovL29jc3AuY29tb2RvY2EuY29tMA0GCSqGSIb3DQEBDAUAA4IBAQAS
# v6Hvi3SamES4aUa1qyQKDKSKZ7g6gb9Fin1SB6iNH04hhTmja14tIIa/ELiueTtT
# zbT72ES+BtlcY2fUQBaHRIZyKtYyFfUSg8L54V0RQGf2QidyxSPiAjgaTCDi2wH3
# zUZPJqJ8ZsBRNraJAlTH/Fj7bADu/pimLpWhDFMpH2/YGaZPnvesCepdgsaLr4Cn
# vYFIUoQx2jLsFeSmTD1sOXPUC4U5IOCFGmjhp0g4qdE2JXfBjRkWxYhMZn0vY86Y
# 6GnfrDyoXZ3JHFuu2PMvdM+4fvbXg50RlmKarkUT2n/cR/vfw1Kf5gZV6Z2M8jpi
# UbzsJA8p1FiAhORFe1rYMIIGGjCCBAKgAwIBAgIQYh1tDFIBnjuQeRUgiSEcCjAN
# BgkqhkiG9w0BAQwFADBWMQswCQYDVQQGEwJHQjEYMBYGA1UEChMPU2VjdGlnbyBM
# aW1pdGVkMS0wKwYDVQQDEyRTZWN0aWdvIFB1YmxpYyBDb2RlIFNpZ25pbmcgUm9v
# dCBSNDYwHhcNMjEwMzIyMDAwMDAwWhcNMzYwMzIxMjM1OTU5WjBUMQswCQYDVQQG
# EwJHQjEYMBYGA1UEChMPU2VjdGlnbyBMaW1pdGVkMSswKQYDVQQDEyJTZWN0aWdv
# IFB1YmxpYyBDb2RlIFNpZ25pbmcgQ0EgUjM2MIIBojANBgkqhkiG9w0BAQEFAAOC
# AY8AMIIBigKCAYEAmyudU/o1P45gBkNqwM/1f/bIU1MYyM7TbH78WAeVF3llMwsR
# HgBGRmxDeEDIArCS2VCoVk4Y/8j6stIkmYV5Gej4NgNjVQ4BYoDjGMwdjioXan1h
# laGFt4Wk9vT0k2oWJMJjL9G//N523hAm4jF4UjrW2pvv9+hdPX8tbbAfI3v0VdJi
# JPFy/7XwiunD7mBxNtecM6ytIdUlh08T2z7mJEXZD9OWcJkZk5wDuf2q52PN43jc
# 4T9OkoXZ0arWZVeffvMr/iiIROSCzKoDmWABDRzV/UiQ5vqsaeFaqQdzFf4ed8pe
# NWh1OaZXnYvZQgWx/SXiJDRSAolRzZEZquE6cbcH747FHncs/Kzcn0Ccv2jrOW+L
# PmnOyB+tAfiWu01TPhCr9VrkxsHC5qFNxaThTG5j4/Kc+ODD2dX/fmBECELcvzUH
# f9shoFvrn35XGf2RPaNTO2uSZ6n9otv7jElspkfK9qEATHZcodp+R4q2OIypxR//
# YEb3fkDn3UayWW9bAgMBAAGjggFkMIIBYDAfBgNVHSMEGDAWgBQy65Ka/zWWSC8o
# QEJwIDaRXBeF5jAdBgNVHQ4EFgQUDyrLIIcouOxvSK4rVKYpqhekzQwwDgYDVR0P
# AQH/BAQDAgGGMBIGA1UdEwEB/wQIMAYBAf8CAQAwEwYDVR0lBAwwCgYIKwYBBQUH
# AwMwGwYDVR0gBBQwEjAGBgRVHSAAMAgGBmeBDAEEATBLBgNVHR8ERDBCMECgPqA8
# hjpodHRwOi8vY3JsLnNlY3RpZ28uY29tL1NlY3RpZ29QdWJsaWNDb2RlU2lnbmlu
# Z1Jvb3RSNDYuY3JsMHsGCCsGAQUFBwEBBG8wbTBGBggrBgEFBQcwAoY6aHR0cDov
# L2NydC5zZWN0aWdvLmNvbS9TZWN0aWdvUHVibGljQ29kZVNpZ25pbmdSb290UjQ2
# LnA3YzAjBggrBgEFBQcwAYYXaHR0cDovL29jc3Auc2VjdGlnby5jb20wDQYJKoZI
# hvcNAQEMBQADggIBAAb/guF3YzZue6EVIJsT/wT+mHVEYcNWlXHRkT+FoetAQLHI
# 1uBy/YXKZDk8+Y1LoNqHrp22AKMGxQtgCivnDHFyAQ9GXTmlk7MjcgQbDCx6mn7y
# IawsppWkvfPkKaAQsiqaT9DnMWBHVNIabGqgQSGTrQWo43MOfsPynhbz2Hyxf5XW
# KZpRvr3dMapandPfYgoZ8iDL2OR3sYztgJrbG6VZ9DoTXFm1g0Rf97Aaen1l4c+w
# 3DC+IkwFkvjFV3jS49ZSc4lShKK6BrPTJYs4NG1DGzmpToTnwoqZ8fAmi2XlZnuc
# hC4NPSZaPATHvNIzt+z1PHo35D/f7j2pO1S8BCysQDHCbM5Mnomnq5aYcKCsdbh0
# czchOm8bkinLrYrKpii+Tk7pwL7TjRKLXkomm5D1Umds++pip8wH2cQpf93at3VD
# cOK4N7EwoIJB0kak6pSzEu4I64U6gZs7tS/dGNSljf2OSSnRr7KWzq03zl8l75jy
# +hOds9TWSenLbjBQUGR96cFr6lEUfAIEHVC1L68Y1GGxx4/eRI82ut83axHMViw1
# +sVpbPxg51Tbnio1lB93079WPFnYaOvfGAA0e0zcfF/M9gXr+korwQTh2Prqooq2
# bYNMvUoUKD85gnJ+t0smrWrb8dee2CvYZXD5laGtaAxOfy/VKNmwuWuAh9kcMIIG
# 7DCCBNSgAwIBAgIQMA9vrN1mmHR8qUY2p3gtuTANBgkqhkiG9w0BAQwFADCBiDEL
# MAkGA1UEBhMCVVMxEzARBgNVBAgTCk5ldyBKZXJzZXkxFDASBgNVBAcTC0plcnNl
# eSBDaXR5MR4wHAYDVQQKExVUaGUgVVNFUlRSVVNUIE5ldHdvcmsxLjAsBgNVBAMT
# JVVTRVJUcnVzdCBSU0EgQ2VydGlmaWNhdGlvbiBBdXRob3JpdHkwHhcNMTkwNTAy
# MDAwMDAwWhcNMzgwMTE4MjM1OTU5WjB9MQswCQYDVQQGEwJHQjEbMBkGA1UECBMS
# R3JlYXRlciBNYW5jaGVzdGVyMRAwDgYDVQQHEwdTYWxmb3JkMRgwFgYDVQQKEw9T
# ZWN0aWdvIExpbWl0ZWQxJTAjBgNVBAMTHFNlY3RpZ28gUlNBIFRpbWUgU3RhbXBp
# bmcgQ0EwggIiMA0GCSqGSIb3DQEBAQUAA4ICDwAwggIKAoICAQDIGwGv2Sx+iJl9
# AZg/IJC9nIAhVJO5z6A+U++zWsB21hoEpc5Hg7XrxMxJNMvzRWW5+adkFiYJ+9Uy
# UnkuyWPCE5u2hj8BBZJmbyGr1XEQeYf0RirNxFrJ29ddSU1yVg/cyeNTmDoqHvzO
# WEnTv/M5u7mkI0Ks0BXDf56iXNc48RaycNOjxN+zxXKsLgp3/A2UUrf8H5VzJD0B
# KLwPDU+zkQGObp0ndVXRFzs0IXuXAZSvf4DP0REKV4TJf1bgvUacgr6Unb+0ILBg
# frhN9Q0/29DqhYyKVnHRLZRMyIw80xSinL0m/9NTIMdgaZtYClT0Bef9Maz5yIUX
# x7gpGaQpL0bj3duRX58/Nj4OMGcrRrc1r5a+2kxgzKi7nw0U1BjEMJh0giHPYla1
# IXMSHv2qyghYh3ekFesZVf/QOVQtJu5FGjpvzdeE8NfwKMVPZIMC1Pvi3vG8Aij0
# bdonigbSlofe6GsO8Ft96XZpkyAcSpcsdxkrk5WYnJee647BeFbGRCXfBhKaBi2f
# A179g6JTZ8qx+o2hZMmIklnLqEbAyfKm/31X2xJ2+opBJNQb/HKlFKLUrUMcpEmL
# QTkUAx4p+hulIq6lw02C0I3aa7fb9xhAV3PwcaP7Sn1FNsH3jYL6uckNU4B9+rY5
# WDLvbxhQiddPnTO9GrWdod6VQXqngwIDAQABo4IBWjCCAVYwHwYDVR0jBBgwFoAU
# U3m/WqorSs9UgOHYm8Cd8rIDZsswHQYDVR0OBBYEFBqh+GEZIA/DQXdFKI7RNV8G
# EgRVMA4GA1UdDwEB/wQEAwIBhjASBgNVHRMBAf8ECDAGAQH/AgEAMBMGA1UdJQQM
# MAoGCCsGAQUFBwMIMBEGA1UdIAQKMAgwBgYEVR0gADBQBgNVHR8ESTBHMEWgQ6BB
# hj9odHRwOi8vY3JsLnVzZXJ0cnVzdC5jb20vVVNFUlRydXN0UlNBQ2VydGlmaWNh
# dGlvbkF1dGhvcml0eS5jcmwwdgYIKwYBBQUHAQEEajBoMD8GCCsGAQUFBzAChjNo
# dHRwOi8vY3J0LnVzZXJ0cnVzdC5jb20vVVNFUlRydXN0UlNBQWRkVHJ1c3RDQS5j
# cnQwJQYIKwYBBQUHMAGGGWh0dHA6Ly9vY3NwLnVzZXJ0cnVzdC5jb20wDQYJKoZI
# hvcNAQEMBQADggIBAG1UgaUzXRbhtVOBkXXfA3oyCy0lhBGysNsqfSoF9bw7J/Ra
# oLlJWZApbGHLtVDb4n35nwDvQMOt0+LkVvlYQc/xQuUQff+wdB+PxlwJ+TNe6qAc
# Jlhc87QRD9XVw+K81Vh4v0h24URnbY+wQxAPjeT5OGK/EwHFhaNMxcyyUzCVpNb0
# llYIuM1cfwGWvnJSajtCN3wWeDmTk5SbsdyybUFtZ83Jb5A9f0VywRsj1sJVhGbk
# s8VmBvbz1kteraMrQoohkv6ob1olcGKBc2NeoLvY3NdK0z2vgwY4Eh0khy3k/ALW
# PncEvAQ2ted3y5wujSMYuaPCRx3wXdahc1cFaJqnyTdlHb7qvNhCg0MFpYumCf/R
# oZSmTqo9CfUFbLfSZFrYKiLCS53xOV5M3kg9mzSWmglfjv33sVKRzj+J9hyhtal1
# H3G/W0NdZT1QgW6r8NDT/LKzH7aZlib0PHmLXGTMze4nmuWgwAxyh8FuTVrTHurw
# ROYybxzrF06Uw3hlIDsPQaof6aFBnf6xuKBlKjTg3qj5PObBMLvAoGMs/FwWAKjQ
# xH/qEZ0eBsambTJdtDgJK0kHqv3sMNrxpy/Pt/360KOE2See+wFmd7lWEOEgbsau
# sfm2usg1XTN2jvF8IAwqd661ogKGuinutFoAsYyr4/kKyVRd1LlqdJ69SK6YMIIH
# BzCCBO+gAwIBAgIRAIx3oACP9NGwxj2fOkiDjWswDQYJKoZIhvcNAQEMBQAwfTEL
# MAkGA1UEBhMCR0IxGzAZBgNVBAgTEkdyZWF0ZXIgTWFuY2hlc3RlcjEQMA4GA1UE
# BxMHU2FsZm9yZDEYMBYGA1UEChMPU2VjdGlnbyBMaW1pdGVkMSUwIwYDVQQDExxT
# ZWN0aWdvIFJTQSBUaW1lIFN0YW1waW5nIENBMB4XDTIwMTAyMzAwMDAwMFoXDTMy
# MDEyMjIzNTk1OVowgYQxCzAJBgNVBAYTAkdCMRswGQYDVQQIExJHcmVhdGVyIE1h
# bmNoZXN0ZXIxEDAOBgNVBAcTB1NhbGZvcmQxGDAWBgNVBAoTD1NlY3RpZ28gTGlt
# aXRlZDEsMCoGA1UEAwwjU2VjdGlnbyBSU0EgVGltZSBTdGFtcGluZyBTaWduZXIg
# IzIwggIiMA0GCSqGSIb3DQEBAQUAA4ICDwAwggIKAoICAQCRh0ssi8HxHqCe0wfG
# AcpSsL55eV0JZgYtLzV9u8D7J9pCalkbJUzq70DWmn4yyGqBfbRcPlYQgTU6IjaM
# +/ggKYesdNAbYrw/ZIcCX+/FgO8GHNxeTpOHuJreTAdOhcxwxQ177MPZ45fpyxnb
# VkVs7ksgbMk+bP3wm/Eo+JGZqvxawZqCIDq37+fWuCVJwjkbh4E5y8O3Os2fUAQf
# GpmkgAJNHQWoVdNtUoCD5m5IpV/BiVhgiu/xrM2HYxiOdMuEh0FpY4G89h+qfNfB
# Qc6tq3aLIIDULZUHjcf1CxcemuXWmWlRx06mnSlv53mTDTJjU67MximKIMFgxvIC
# LMT5yCLf+SeCoYNRwrzJghohhLKXvNSvRByWgiKVKoVUrvH9Pkl0dPyOrj+lcvTD
# WgGqUKWLdpUbZuvv2t+ULtka60wnfUwF9/gjXcRXyCYFevyBI19UCTgqYtWqyt/t
# z1OrH/ZEnNWZWcVWZFv3jlIPZvyYP0QGE2Ru6eEVYFClsezPuOjJC77FhPfdCp3a
# vClsPVbtv3hntlvIXhQcua+ELXei9zmVN29OfxzGPATWMcV+7z3oUX5xrSR0Gyzc
# +Xyq78J2SWhi1Yv1A9++fY4PNnVGW5N2xIPugr4srjcS8bxWw+StQ8O3ZpZelDL6
# oPariVD6zqDzCIEa0USnzPe4MQIDAQABo4IBeDCCAXQwHwYDVR0jBBgwFoAUGqH4
# YRkgD8NBd0UojtE1XwYSBFUwHQYDVR0OBBYEFGl1N3u7nTVCTr9X05rbnwHRrt7Q
# MA4GA1UdDwEB/wQEAwIGwDAMBgNVHRMBAf8EAjAAMBYGA1UdJQEB/wQMMAoGCCsG
# AQUFBwMIMEAGA1UdIAQ5MDcwNQYMKwYBBAGyMQECAQMIMCUwIwYIKwYBBQUHAgEW
# F2h0dHBzOi8vc2VjdGlnby5jb20vQ1BTMEQGA1UdHwQ9MDswOaA3oDWGM2h0dHA6
# Ly9jcmwuc2VjdGlnby5jb20vU2VjdGlnb1JTQVRpbWVTdGFtcGluZ0NBLmNybDB0
# BggrBgEFBQcBAQRoMGYwPwYIKwYBBQUHMAKGM2h0dHA6Ly9jcnQuc2VjdGlnby5j
# b20vU2VjdGlnb1JTQVRpbWVTdGFtcGluZ0NBLmNydDAjBggrBgEFBQcwAYYXaHR0
# cDovL29jc3Auc2VjdGlnby5jb20wDQYJKoZIhvcNAQEMBQADggIBAEoDeJBCM+x7
# GoMJNjOYVbudQAYwa0Vq8ZQOGVD/WyVeO+E5xFu66ZWQNze93/tk7OWCt5XMV1Vw
# S070qIfdIoWmV7u4ISfUoCoxlIoHIZ6Kvaca9QIVy0RQmYzsProDd6aCApDCLpOp
# viE0dWO54C0PzwE3y42i+rhamq6hep4TkxlVjwmQLt/qiBcW62nW4SW9RQiXgNdU
# IChPynuzs6XSALBgNGXE48XDpeS6hap6adt1pD55aJo2i0OuNtRhcjwOhWINoF5w
# 22QvAcfBoccklKOyPG6yXqLQ+qjRuCUcFubA1X9oGsRlKTUqLYi86q501oLnwIi4
# 4U948FzKwEBcwp/VMhws2jysNvcGUpqjQDAXsCkWmcmqt4hJ9+gLJTO1P22vn18K
# Vt8SscPuzpF36CAT6Vwkx+pEC0rmE4QcTesNtbiGoDCni6GftCzMwBYjyZHlQgNL
# gM7kTeYqAT7AXoWgJKEXQNXb2+eYEKTx6hkbgFT6R4nomIGpdcAO39BolHmhoJ6O
# trdCZsvZ2WsvTdjePjIeIOTsnE1CjZ3HM5mCN0TUJikmQI54L7nu+i/x8Y/+ULh4
# 3RSW3hwOcLAqhWqxbGjpKuQQK24h/dN8nTfkKgbWw/HXaONPB3mBCBP+smRe6bE8
# 5tB4I7IJLOImYr87qZdRzMdEMoGyr8/fMYIEmzCCBJcCAQEwaDBUMQswCQYDVQQG
# EwJHQjEYMBYGA1UEChMPU2VjdGlnbyBMaW1pdGVkMSswKQYDVQQDEyJTZWN0aWdv
# IFB1YmxpYyBDb2RlIFNpZ25pbmcgQ0EgUjM2AhBk8Fn+Wn7V49yEjsf2gHtqMAkG
# BSsOAwIaBQCgeDAYBgorBgEEAYI3AgEMMQowCKACgAChAoAAMBkGCSqGSIb3DQEJ
# AzEMBgorBgEEAYI3AgEEMBwGCisGAQQBgjcCAQsxDjAMBgorBgEEAYI3AgEVMCMG
# CSqGSIb3DQEJBDEWBBS5T9EoOjgi/JH0JfapcKvqXYfd6jALBgcqhkjOPQIBBQAE
# RjBEAiBCj1pkVVd1FzG/BkGCpy3eFIREk9yYs6/J/z4E0UizqwIgCbrEtncBc3wS
# loXwBkQuFWb+0arPkVBAI6MORHHA4FyhggNMMIIDSAYJKoZIhvcNAQkGMYIDOTCC
# AzUCAQEwgZIwfTELMAkGA1UEBhMCR0IxGzAZBgNVBAgTEkdyZWF0ZXIgTWFuY2hl
# c3RlcjEQMA4GA1UEBxMHU2FsZm9yZDEYMBYGA1UEChMPU2VjdGlnbyBMaW1pdGVk
# MSUwIwYDVQQDExxTZWN0aWdvIFJTQSBUaW1lIFN0YW1waW5nIENBAhEAjHegAI/0
# 0bDGPZ86SIONazANBglghkgBZQMEAgIFAKB5MBgGCSqGSIb3DQEJAzELBgkqhkiG
# 9w0BBwEwHAYJKoZIhvcNAQkFMQ8XDTIyMDIwMjEyNDkwM1owPwYJKoZIhvcNAQkE
# MTIEMGBDlfnDcqMY8Ax4V4K8grT6/NPRdTZCOkDW6xfAj+nVTJP1wgpVanvxi2wl
# m/ETzjANBgkqhkiG9w0BAQEFAASCAgA+MjzexTzTKf6YoAKWeIKPZ33x84Spnw+A
# AfFRuEMVqap320Jvw9IzW32XeIEZ4dWbokb1J1MRSmsVZC0emmxlYaibMUNQN4Aw
# XWg0n9KK8AUiN0GuessHEqQ9DP77eGlZWork88Y15DJM47lHZQ2RWvO9qHew8hid
# ulHNw5wyq84hcAMtqpiUo/98W0GyY+HRRwAY/zXOEUQ0A9wfFl8Bp2Wo7o2Jabe4
# DePaSXVK6PBNYiVw/leZUf+JI2bLVISU3/wFbFhhoONiHz/OARgQxBTb9f9LtYWw
# xn6bXqZLsiuA3y52FdqYI9NbnKOZx6DyeJrlBtvCQhFJKFTrwc1uy7YNg0e3huTg
# hDVqmlcM5xWl4rRvr80DJj1E2nY9J1gI7paywuKMi/nJjy7Q4AoANRHTyXWz1tYg
# oBfTgr5SaUgAbxq1t934vEsvXpMNK4TjGp44ifcSdVXWzTq9mIl865PAyeBDPMi3
# rQGVhIF6CCtxRM/V0AkFyUWRJGVElp831A272Ai/8Y1/+xY2Sqp7LWBtX4moiNXh
# DglQgzkfRbzkLNXzkgw/nYaW7gXbtONMeHsPHB2GthfWu/tWHvIRHETNKzh/IgHH
# 7dAtymPeEra/OlrkRQMJwRalQmZi2fKqpouQvJ8zjMAx8qVbhMPVpuIBD6tjOwQE
# JMm+z80vJg==
# SIG # End signature block
