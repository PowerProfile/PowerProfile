#!/usr/bin/env bash

if [ -z "`command -v brew`" ]; then
    if [[ "$(read -e -p '      Install Homebrew now? [y/N]> '; echo $REPLY)" == [YyZz]* ]]; then
        touch /tmp/.com.apple.dt.CommandLineTools.installondemand.in-progress
        softwareupdate -i -a
        rm /tmp/.com.apple.dt.CommandLineTools.installondemand.in-progress
        /usr/bin/env bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    fi
fi
