#!/usr/bin/env bash

cd "$(dirname "${BASH_SOURCE[0]}")"

QMK_FOLDER=~/Documents/Code/Utils/QMK\ Firmware/
KEYMAP_FOLDER=$QMK_FOLDER/keyboards/ergodox/keymaps/sk/

unison "$KEYMAP_FOLDER" "."
