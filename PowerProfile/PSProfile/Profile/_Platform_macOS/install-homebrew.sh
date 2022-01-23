#!/usr/bin/env bash

if [ -z "`command -v brew`" ]; then
    if [[ "$(read -e -p '      Install Homebrew now? [y/N]> '; echo $REPLY)" == [YyZz]* ]]; then
        /usr/bin/env bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    fi
fi
