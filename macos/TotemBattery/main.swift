// TotemBattery: menu bar app showing the Totem halves' battery levels.
//
// The Totem dongle writes "ZMKBAT <slot0> <slot1> <connected>" lines to a
// USB serial port (see src/battery_serial.c). This app finds that port among
// /dev/cu.usbmodem*, reads it, and shows the levels in the menu bar.

import AppKit
import ServiceManagement

// MARK: - Serial port reader

final class SerialReader {
    let path: String
    private let fd: Int32
    private var source: DispatchSourceRead?
    private var buffer = Data()
    var onLine: ((String) -> Void)?
    var onClose: (() -> Void)?

    init?(path: String) {
        self.path = path
        fd = open(path, O_RDONLY | O_NOCTTY | O_NONBLOCK)
        guard fd >= 0 else { return nil }

        var tio = termios()
        tcgetattr(fd, &tio)
        cfmakeraw(&tio)
        tio.c_cflag |= tcflag_t(CLOCAL | CREAD)
        cfsetspeed(&tio, speed_t(B115200))
        tcsetattr(fd, TCSANOW, &tio)
    }

    func start() {
        let src = DispatchSource.makeReadSource(fileDescriptor: fd, queue: .main)
        src.setEventHandler { [weak self] in self?.readAvailable() }
        src.setCancelHandler { [fd] in close(fd) }
        source = src
        src.resume()
    }

    private func readAvailable() {
        var chunk = [UInt8](repeating: 0, count: 512)
        let n = read(fd, &chunk, chunk.count)
        if n <= 0 {
            if n == 0 || (errno != EAGAIN && errno != EINTR) { stop(); onClose?() }
            return
        }
        buffer.append(contentsOf: chunk[0..<n])
        while let nl = buffer.firstIndex(of: 0x0A) {
            let lineData = buffer[buffer.startIndex..<nl]
            buffer.removeSubrange(buffer.startIndex...nl)
            if let line = String(data: lineData, encoding: .utf8) {
                onLine?(line.trimmingCharacters(in: .whitespacesAndNewlines))
            }
        }
        if buffer.count > 4096 { buffer.removeAll() }
    }

    func stop() {
        source?.cancel()
        source = nil
    }
}

// MARK: - App

struct BatteryState {
    var levels: [Int] = [-1, -1]
    var connected = 0
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let menu = NSMenu()

    private var active: SerialReader?
    private var probing: [String: SerialReader] = [:]
    private var state: BatteryState?
    private var lastUpdate: Date?
    private var blinkTimer: Timer?

    private var swapped: Bool {
        get { UserDefaults.standard.bool(forKey: "swapHalves") }
        set { UserDefaults.standard.set(newValue, forKey: "swapHalves") }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem.button?.font = NSFont.monospacedDigitSystemFont(ofSize: 0, weight: .regular)
        statusItem.menu = menu
        menu.delegate = self
        render()

        Timer.scheduledTimer(withTimeInterval: 3, repeats: true) { [weak self] _ in self?.tick() }
        tick()
    }

    // Look for the dongle when not connected, and drop stale data.
    private func tick() {
        if active == nil { scanPorts() }
        if let last = lastUpdate, Date().timeIntervalSince(last) > 20 {
            active?.stop()
            active = nil
            state = nil
            lastUpdate = nil
        }
        render()
    }

    private func scanPorts() {
        let dev = (try? FileManager.default.contentsOfDirectory(atPath: "/dev")) ?? []
        for name in dev where name.hasPrefix("cu.usbmodem") {
            let path = "/dev/" + name
            guard probing[path] == nil, let reader = SerialReader(path: path) else { continue }
            probing[path] = reader
            reader.onLine = { [weak self, weak reader] line in
                guard let self, let reader else { return }
                self.handle(line: line, from: reader)
            }
            reader.onClose = { [weak self] in
                guard let self else { return }
                self.probing[path] = nil
                if self.active?.path == path { self.active = nil; self.state = nil; self.render() }
            }
            reader.start()
            // Give each candidate port a few report intervals to identify itself.
            DispatchQueue.main.asyncAfter(deadline: .now() + 12) { [weak self] in
                guard let self, self.active?.path != path, let r = self.probing[path] else { return }
                r.stop()
                self.probing[path] = nil
            }
        }
    }

    private func handle(line: String, from reader: SerialReader) {
        let parts = line.split(separator: " ")
        guard parts.count == 4, parts[0] == "ZMKBAT",
              let a = Int(parts[1]), let b = Int(parts[2]), let c = Int(parts[3]) else { return }

        if active !== reader {
            active = reader
            for (path, other) in probing where other !== reader { other.stop(); probing[path] = nil }
        }
        state = BatteryState(levels: [a, b], connected: c)
        lastUpdate = Date()
        render()
    }

    private var leftRight: (Int, Int)? {
        guard let s = state else { return nil }
        return swapped ? (s.levels[1], s.levels[0]) : (s.levels[0], s.levels[1])
    }

    private func fmt(_ level: Int) -> String { level < 0 ? "–" : "\(level)%" }

    private func render() {
        guard let button = statusItem.button else { return }
        if let (l, r) = leftRight, let s = state {
            let warn = s.connected < 2 ? " ⚠︎" : ""
            button.title = "L \(fmt(l))  R \(fmt(r))\(warn)"
            let low = [l, r].contains { $0 >= 0 && $0 <= 15 }
            button.contentTintColor = low ? .systemRed : nil
            setBlinking(low)
        } else {
            button.title = "⌨︎ –"
            button.contentTintColor = nil
            setBlinking(false)
        }
    }

    // Pulse the menu bar readout while a half is low.
    private func setBlinking(_ on: Bool) {
        guard let button = statusItem.button else { return }
        if on {
            guard blinkTimer == nil else { return }
            blinkTimer = Timer.scheduledTimer(withTimeInterval: 0.6, repeats: true) { _ in
                button.alphaValue = button.alphaValue < 1 ? 1 : 0.2
            }
        } else {
            blinkTimer?.invalidate()
            blinkTimer = nil
            button.alphaValue = 1
        }
    }

    private func rebuildMenu() {
        menu.removeAllItems()
        if let (l, r) = leftRight, let s = state {
            menu.addItem(withTitle: "Left: \(fmt(l))", action: nil, keyEquivalent: "")
            menu.addItem(withTitle: "Right: \(fmt(r))", action: nil, keyEquivalent: "")
            menu.addItem(withTitle: "Halves connected to dongle: \(s.connected)/2", action: nil, keyEquivalent: "")
            if let p = active?.path {
                menu.addItem(withTitle: "Port: \(p)", action: nil, keyEquivalent: "")
            }
        } else {
            menu.addItem(withTitle: "Totem dongle not found", action: nil, keyEquivalent: "")
        }
        menu.addItem(.separator())

        let swap = NSMenuItem(title: "Swap Left/Right", action: #selector(toggleSwap), keyEquivalent: "")
        swap.target = self
        swap.state = swapped ? .on : .off
        menu.addItem(swap)

        let login = NSMenuItem(title: "Open at Login", action: #selector(toggleLogin), keyEquivalent: "")
        login.target = self
        login.state = SMAppService.mainApp.status == .enabled ? .on : .off
        menu.addItem(login)

        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit TotemBattery", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
    }

    @objc private func toggleSwap() { swapped.toggle(); render() }

    @objc private func toggleLogin() {
        do {
            if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
        } catch {
            let alert = NSAlert(error: error)
            alert.messageText = "Couldn't change the login item. Move TotemBattery to /Applications and try again."
            alert.runModal()
        }
    }
}

extension AppDelegate: NSMenuDelegate {
    func menuNeedsUpdate(_ menu: NSMenu) { rebuildMenu() }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
