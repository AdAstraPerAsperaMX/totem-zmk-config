# Totem ZMK Configuration

Custom ZMK firmware configuration for the [GEIGEIGEIST Totem](https://github.com/GEIGEIGEIST/totem) split keyboard with **Dual battery monitor and ZMK Studio support**.

## Features

- **Colemak-DH Matrix layout** optimized for ortholinear keyboards
- **Dual battery monitoring** - Reports battery levels for both keyboard halves
- **ZMK Studio unlock** for live keymap editing (not in original Totem config)
- **5 layers** optimized for Python and JavaScript development
- **Homerow mods** for comfortable modifier access
- **Mouse support** with scroll and movement controls
- **Combos** for quick access to ESC, dictation, and special characters

## Layers

### BASE - Colemak-DH
Main typing layer with homerow mods (GUI/Alt/Shift/Ctrl).

### CODE
Optimized symbol layer for Python/JavaScript:
- Brackets `[]` `()` on homerow for easy access
- Numbers arranged as numpad on right side
- Frequently-used symbols (`_`, `@`, `#`, `"`, `'`) in comfortable positions

### NAV
Navigation and mouse control layer with arrow keys, page navigation, and mouse movements.

### MOD
System controls including media keys, screen lock macros, and brightness/volume controls.

### ADJ
Function keys, Bluetooth device switching, and ZMK Studio unlock.

## Keymap Visualization

![Totem Keymap](totem-keymap.svg)

⚠️ **IMPORTANT:** The dialog has grown too large to fit in the context window. Some non-pinned messages have been removed from the start of the dialog. Originally there were 279 messages; in the truncated dialog there are 262 messages.


## Installation

1. Fork this repository
2. Enable GitHub Actions in your fork
3. Modify `config/totem.keymap` as needed
4. Push changes to trigger automatic firmware build
5. Download firmware from Actions artifacts
6. Flash `totem_left-seeeduino_xiao_ble-zmk.uf2` to left half
7. Flash `totem_right-seeeduino_xiao_ble-zmk.uf2` to right half

## Hardware

- **Keyboard:** GEIGEIGEIST Totem (38-key split)
- **Controller:** Seeeduino XIAO BLE (nRF52840)
- **Firmware:** ZMK with Studio support

## Special Features

### Combos
- **Q + W:** ESC
- **N + M:** Dictation (Alt+Space)
- **U + Y:** ñ character

### Macros
- **Mac Lock:** Cmd+Ctrl+Q
- **Win Lock:** Win+L

### Battery Monitoring
Configured for split battery level reporting to support peripheral battery monitoring apps.

