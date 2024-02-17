#!/usr/bin/env bash

cd "$(dirname "${BASH_SOURCE[0]}")"

QMK_FOLDER=~/Documents/Code/Repos/QMK\ Firmware
KEYMAP_FOLDER=$QMK_FOLDER/keyboards/ergodox_ez/keymaps/ergodox_sk_exp/

unison "$KEYMAP_FOLDER" "."
