#include QMK_KEYBOARD_H
#include "version.h"

#define KC_CTES CTL_T(KC_ESC)
#define KC_SHT4 SGUI(KC_4)
#define KC_SHT6 SGUI(KC_6)

#define KC_BRUP KC_F15
#define KC_BRDN KC_F14

#define KC_CMDN RGUI(KC_DOWN)
#define KC_CMUP RGUI(KC_UP)
#define KC_CMLB RGUI(KC_LCBR)
#define KC_CMRB RGUI(KC_RCBR)

#define KC_ULTR (QK_LCTL | QK_LALT | QK_LGUI)

enum layers {
    BASE,
    FN,
};

// clang-format off
const uint16_t PROGMEM keymaps[][MATRIX_ROWS][MATRIX_COLS] = {
/* Keymap 0: Basic layer
 *
 * ,--------------------------------------------------.           ,--------------------------------------------------.
 * |   =+   |   1  |   2  |   3  |   4  |   5  | SHT4 |           | SHT6 |   6  |   7  |   8  |   9  |   0  |   -_   |
 * |--------+------+------+------+------+-------------|           |------+------+------+------+------+------+--------|
 * | Tab    |   Q  |   W  |   E  |   R  |   T  |      |           |      |   Y  |   U  |   I  |   O  |   P  |   \|   |
 * |--------+------+------+------+------+------|      |           |      |------+------+------+------+------+--------|
 * |Esc/Ctrl|   A  |   S  |   D  |   F  |   G  |------|           |------|   H  |   J  |   K  |   L  |  :;  |   "'   |
 * |--------+------+------+------+------+------|      |           |      |------+------+------+------+------+--------|
 * | LShift |   Z  |   X  |   C  |   V  |   B  |      |           |      |   N  |   M  |  <,  |  >.  |   ?/ | RShift |
 * `--------+------+------+------+------+-------------'           `-------------+------+------+------+------+--------'
 *   | LAlt | LGui |      |   [  |   ]  |                                       |      |      |      | RGui | RAlt |
 *   `----------------------------------'                                       `----------------------------------'
 *                                        ,-------------.       ,-------------.
 *                                        |      |      |       |      |      |
 *                                 ,------|------|------|       |------+------+------.
 *                                 |      |      |      |       |      |      |      |
 *                                 |Backsp|Delete|------|       |------|Enter |Space |
 *                                 |      |      |Ultra |       |  Fn  |      |      |
 *                                 `--------------------'       `--------------------'
 */
[BASE] = LAYOUT_ergodox(
// left hand
    KC_EQL,  KC_1,     KC_2,    KC_3,    KC_4,     KC_5,      KC_SHT4,
    KC_TAB,  KC_Q,     KC_W,    KC_E,    KC_R,     KC_T,      KC_NO,
    KC_CTES, KC_A,     KC_S,    KC_D,    KC_F,     KC_G,
    KC_LSFT, KC_Z,     KC_X,    KC_C,    KC_V,     KC_B,      KC_NO,
    KC_LALT, KC_LGUI,  KC_NO,   KC_LBRC, KC_RBRC,
                                                   KC_NO,     KC_NO,
                                                              KC_NO,
                                          KC_BSPC, KC_DELETE, KC_ULTR,

// right hand
    KC_SHT6, KC_6,     KC_7,  KC_8,    KC_9,     KC_0,    KC_MINS,
    KC_NO,   KC_Y,     KC_U,  KC_I,    KC_O,     KC_P,    KC_BSLS,
             KC_H,     KC_J,  KC_K,    KC_L,     KC_SCLN, KC_QUOT,
    KC_NO,   KC_N,     KC_M,  KC_COMM, KC_DOT,   KC_SLSH, KC_RSFT,
                       KC_NO, KC_NO,   KC_NO,    KC_RGUI, KC_RALT,
    KC_NO,   KC_NO,
    KC_NO,
    MO(FN),  KC_ENTER, KC_SPACE
),
/* Keymap 1: Fn Layer
 *
 * ,--------------------------------------------------.           ,--------------------------------------------------.
 * |        | BrDn | BrUp |      |      |      |      |           |      | Prev | Play | Next |VolDn |VolUp |  Mute  |
 * |--------+------+------+------+------+-------------|           |------+------+------+------+------+------+--------|
 * |        |      |      |      |      |      |      |           |      |      |      |      |      |      |        |
 * |--------+------+------+------+------+------|      |           |      |------+------+------+------+------+--------|
 * |        |      |      |      |      |   `  |------|           |------| Left | Down | Up   |Right |      |        |
 * |--------+------+------+------+------+------|      |           |      |------+------+------+------+------+--------|
 * |        |      |      |      |      |   ~  |      |           |      | Cmd{ | CmdDn| CmdUp| Cmd} |      |        |
 * `--------+------+------+------+------+-------------'           `-------------+------+------+------+------+--------'
 *   |      |      |      |      |      |                                       |      |      |      |      |      |
 *   `----------------------------------'                                       `----------------------------------'
 *                                        ,-------------.       ,-------------.
 *                                        |      |      |       |      |      |
 *                                 ,------|------|------|       |------+------+------.
 *                                 |      |      |      |       |      |      |      |
 *                                 |      |      |------|       |------|      |      |
 *                                 |      |      |      |       |      |      |      |
 *                                 `--------------------'       `--------------------'
 */
[FN] = LAYOUT_ergodox(
// left hand
    KC_TRNS, KC_BRDN, KC_BRUP, KC_TRNS, KC_TRNS, KC_TRNS, KC_TRNS,
    KC_TRNS, KC_TRNS, KC_TRNS, KC_TRNS, KC_TRNS, KC_TRNS, KC_TRNS,
    KC_TRNS, KC_TRNS, KC_TRNS, KC_TRNS, KC_TRNS, KC_GRV,
    KC_TRNS, KC_TRNS, KC_TRNS, KC_TRNS, KC_TRNS, KC_TILD, KC_TRNS,
    KC_TRNS, KC_TRNS, KC_TRNS, KC_TRNS, KC_TRNS,
                                                 KC_TRNS, KC_TRNS,
                                                          KC_TRNS,
                                        KC_TRNS, KC_TRNS, KC_TRNS,

// right hand
    KC_TRNS, KC_MPRV, KC_MPLY, KC_MNXT, KC_VOLD,  KC_VOLU, KC_MUTE,
    KC_TRNS, KC_TRNS, KC_TRNS, KC_TRNS, KC_TRNS,  KC_TRNS, KC_TRNS,
             KC_LEFT, KC_DOWN, KC_UP,   KC_RIGHT, KC_TRNS, KC_TRNS,
    KC_TRNS, KC_CMLB, KC_CMDN, KC_CMUP, KC_CMRB,  KC_TRNS, KC_TRNS,
                      KC_TRNS, KC_TRNS, KC_TRNS,  KC_TRNS, KC_TRNS,
    KC_TRNS, KC_TRNS,
    KC_TRNS,
    KC_TRNS, KC_TRNS, KC_TRNS
)
};

// Runs just one time when the keyboard initializes.
void keyboard_post_init_user(void) {
};

// Runs whenever there is a layer state change.
layer_state_t layer_state_set_user(layer_state_t state) {
    // ergodox_board_led_off();
    // ergodox_right_led_1_off();
    // ergodox_right_led_2_off();
    // ergodox_right_led_3_off();

    return state;
};
