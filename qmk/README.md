# Info

1. pull `qmk-firmware` repo
2. `$ nix-shell` 
3. `$ make git-submodule`
4. `$ cd keyboards/ergodox_ez/keympas && ln -s THIS_PATH/ergodox_sk ergodox_sk`
5. `$ qmk compile -kb ergodox_ez/base -km ergodox_sk`
6. use [Teensy Loader](https://www.pjrc.com/teensy/loader_mac.html) for uploading the compiled binary (found in the root `qmk-firmware` folder)

