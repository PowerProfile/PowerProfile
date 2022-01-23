#!/usr/bin/env bash

export HOMEBREW_NO_AUTO_UPDATE=1
export HOMEBREW_AUTO_UPDATING=0
export HOMEBREW_UPDATE_PREINSTALL=0
(brew bundle check --quiet --no-upgrade --file="$1" >/dev/null || brew bundle install --quiet --no-upgrade --no-lock --force --file="$1")
