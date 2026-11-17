# Custom code for this config, built as a Zephyr module (see zephyr/module.yml).
target_sources_ifdef(CONFIG_ZMK_BATTERY_SERIAL_REPORT app PRIVATE src/battery_serial.c)
