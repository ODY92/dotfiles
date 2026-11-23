pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property var disks: []
    property string manualPrimaryMount: ""

    readonly property var primaryDisk: {
        if (!disks || !disks.length)
            return null;
        if (manualPrimaryMount) {
            const match = disks.find(d => d.mount === manualPrimaryMount);
            if (match)
                return match;
        }
        return disks.find(d => d.mount === "/") ?? disks[0];
    }

    readonly property real percentage: primaryDisk?.perc ?? 0

    function refresh(): void {
        if (!proc.running)
            proc.running = true;
    }

    Process {
        id: proc

        running: true
        command: [
            "python3",
            "-c",
            "import os, json\nseen = set()\ndisks = []\nwith open('/proc/mounts') as f:\n    for line in f:\n        parts = line.split()\n        if len(parts) < 3: continue\n        dev, mnt, fstype = parts[0], parts[1], parts[2]\n        if not dev.startswith('/dev/') or fstype in ('autofs', 'squashfs', 'tmpfs', 'devtmpfs'):\n            continue\n        if dev in seen: continue\n        seen.add(dev)\n        mnt_dec = mnt.encode('utf-8').decode('unicode_escape')\n        try:\n            st = os.statvfs(mnt_dec)\n            total = (st.f_blocks * st.f_frsize) // 1024\n            used = ((st.f_blocks - st.f_bfree) * st.f_frsize) // 1024\n            if total <= 0: continue\n            disks.append({'mount': mnt_dec, 'device': dev, 'used': used, 'total': total, 'perc': used / total})\n        except OSError:\n            pass\nprint(json.dumps(disks))"
        ]
        stdout: SplitParser {
            onRead: data => {
                try {
                    const parsed = JSON.parse(data.trim());
                    if (Array.isArray(parsed))
                        root.disks = parsed;
                } catch (e) {}
            }
        }
    }

    Timer {
        interval: 10000
        running: true
        repeat: true
        onTriggered: root.refresh()
    }
}
