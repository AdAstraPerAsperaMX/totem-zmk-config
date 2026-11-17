/*
 * Writes split peripheral battery levels to a USB CDC ACM serial port so a
 * host app can display them (USB HID has no battery reporting in ZMK).
 *
 * Line format, sent on every change and every
 * CONFIG_ZMK_BATTERY_SERIAL_REPORT_INTERVAL_MS:
 *
 *   ZMKBAT <slot0 level> <slot1 level> <connected peripherals>\n
 *
 * Levels are 0-100, or -1 if not known yet. Slot numbers are the order in
 * which the halves were first paired with the dongle.
 */

#include <stdio.h>

#include <zephyr/bluetooth/conn.h>
#include <zephyr/device.h>
#include <zephyr/drivers/uart.h>
#include <zephyr/init.h>
#include <zephyr/kernel.h>
#include <zephyr/logging/log.h>

#include <zmk/event_manager.h>
#include <zmk/events/battery_state_changed.h>

LOG_MODULE_DECLARE(zmk, CONFIG_ZMK_LOG_LEVEL);

#define SLOTS 2

static const struct device *uart = DEVICE_DT_GET(DT_CHOSEN(zmk_battery_serial));

static int8_t levels[SLOTS] = {-1, -1};
static atomic_t connected_peripherals = ATOMIC_INIT(0);

static void report_work_handler(struct k_work *work);
static K_WORK_DELAYABLE_DEFINE(report_work, report_work_handler);

static void report_work_handler(struct k_work *work) {
    char line[48];
    int len = snprintf(line, sizeof(line), "ZMKBAT %d %d %d\n", levels[0], levels[1],
                       (int)atomic_get(&connected_peripherals));

    for (int i = 0; i < len && i < (int)sizeof(line); i++) {
        uart_poll_out(uart, line[i]);
    }

    k_work_reschedule(&report_work, K_MSEC(CONFIG_ZMK_BATTERY_SERIAL_REPORT_INTERVAL_MS));
}

static void report_soon(void) { k_work_reschedule(&report_work, K_MSEC(50)); }

static int battery_serial_listener(const zmk_event_t *eh) {
    const struct zmk_peripheral_battery_state_changed *ev =
        as_zmk_peripheral_battery_state_changed(eh);
    if (ev == NULL || ev->source >= SLOTS) {
        return ZMK_EV_EVENT_BUBBLE;
    }

    levels[ev->source] = ev->state_of_charge;
    report_soon();
    return ZMK_EV_EVENT_BUBBLE;
}

ZMK_LISTENER(battery_serial, battery_serial_listener);
ZMK_SUBSCRIPTION(battery_serial, zmk_peripheral_battery_state_changed);

/* Count connections where the dongle is the BLE central, i.e. the halves. */
static void on_connected(struct bt_conn *conn, uint8_t err) {
    struct bt_conn_info info;
    if (err || bt_conn_get_info(conn, &info) || info.role != BT_CONN_ROLE_CENTRAL) {
        return;
    }
    atomic_inc(&connected_peripherals);
    report_soon();
}

static void on_disconnected(struct bt_conn *conn, uint8_t reason) {
    struct bt_conn_info info;
    if (bt_conn_get_info(conn, &info) || info.role != BT_CONN_ROLE_CENTRAL) {
        return;
    }
    if (atomic_dec(&connected_peripherals) <= 0) {
        atomic_set(&connected_peripherals, 0);
    }
    report_soon();
}

BT_CONN_CB_DEFINE(battery_serial_conn_cb) = {
    .connected = on_connected,
    .disconnected = on_disconnected,
};

static int battery_serial_init(void) {
    if (!device_is_ready(uart)) {
        LOG_ERR("Battery serial UART not ready");
        return -ENODEV;
    }
    k_work_schedule(&report_work, K_SECONDS(2));
    return 0;
}

SYS_INIT(battery_serial_init, APPLICATION, CONFIG_APPLICATION_INIT_PRIORITY);
