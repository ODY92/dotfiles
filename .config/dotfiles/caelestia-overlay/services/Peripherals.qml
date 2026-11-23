pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property string headsetName: "Logitech PRO X Wireless"
    property bool headsetPresent: false
    property bool headsetOnline: false
    property int headsetPercent: -1
    property bool headsetCharging: false
    property int headsetVoltageMv: 0
    property string headsetStatus: "not_found"
    property string headsetHidraw: ""

    property string mouseName: "Attack Shark 2.4G"
    property bool mousePresent: false
    property bool mouseOnline: false
    property int mousePercent: -1
    property bool mouseCharging: false
    property bool mouseWired: false
    property bool mouseSleeping: false
    property string mouseStatus: "not_found"
    property string mouseHidraw: ""

    readonly property bool hasAny: headsetPresent || mousePresent

    function applyPayload(line: string): void {
        const trimmed = (line ?? "").trim();
        if (!trimmed)
            return;
        try {
            const data = JSON.parse(trimmed);
            if (data.headset) {
                const h = data.headset;
                headsetName = h.name ?? "Casque";
                headsetPresent = !!h.present;
                headsetOnline = !!h.online;
                headsetPercent = typeof h.percent === "number" ? h.percent : -1;
                headsetCharging = !!h.charging;
                headsetVoltageMv = typeof h.voltage_mv === "number" ? h.voltage_mv : 0;
                headsetStatus = h.status ?? "offline";
                headsetHidraw = h.hidraw ?? "";
            }
            if (data.mouse) {
                const m = data.mouse;
                mouseName = m.name ?? "Souris";
                mousePresent = !!m.present;
                mouseOnline = !!m.online;
                mousePercent = typeof m.percent === "number" ? m.percent : -1;
                mouseCharging = !!m.charging;
                mouseWired = !!m.wired;
                mouseSleeping = !!m.sleeping;
                mouseStatus = m.status ?? "offline";
                mouseHidraw = m.hidraw ?? "";
            }
        } catch (e) {
            console.warn("Peripherals: failed to parse payload:", e);
        }
    }

    function refresh(): void {
        if (monitor.running) {
            monitor.write("refresh\n");
        } else {
            monitor.running = true;
        }
    }

    Process {
        id: monitor

        running: true
        stdinEnabled: true
        command: ["python3", Quickshell.shellPath("scripts/peripheral-battery.py")]
        stdout: SplitParser {
            onRead: data => root.applyPayload(data)
        }
        onExited: restartTimer.start()
    }

    Timer {
        id: restartTimer

        interval: 3000
        repeat: false
        onTriggered: monitor.running = true
    }
}
