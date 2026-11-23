#!/usr/bin/env python3
"""
Lightweight peripheral battery monitor for Caelestia Quickshell.
Streams JSON status lines to stdout whenever headset or mouse battery changes.

Supported devices:
- Headset: Logitech PRO X Wireless Gaming Headset (046d:0aba) via HID++ 2.0 0x1F20 ADC
- Mouse: Attack Shark / Xenta / Beken 2.4G Wireless (1d57:fa60, 1d57:fa65) via passive
  HID input report 0x03 on Usage Page 0x000A, plus wired USB PIDs (fa55, 2155, fa71, 2126).
"""

import glob
import json
import os
import select
import signal
import stat
import sys
import time

LOGITECH_VID = 0x046D
HEADSET_PIDS = {
    0x0ABA: "Logitech PRO X Wireless",
}

XENTA_VID = 0x1D57
MOUSE_RECEIVER_PIDS = {0xFA60, 0xFA65}
MOUSE_WIRED_PIDS = {
    0xFA55: "Attack Shark X11",
    0x2155: "Attack Shark",
    0xFA71: "Delux M600 Pro",
    0x2126: "Attack Shark X8 Pro",
}

XENTA_MODELS = {
    0x55: ("Attack Shark X11", False),
    0x4E: ("Attack Shark X3 Max", False),
    0xE5: ("Attack Shark V3 Pro", False),
    0x10: ("Attack Shark X6 / R1", True),
    0x07: ("Attack Shark X11 SE", False),
    0x08: ("Attack Shark X8 Pro", False),
    0x24: ("Attack Shark V6", False),
    0x20: ("Delux M600 Pro", False),
    0x30: ("Delux M900 Pro", False),
    0x50: ("Delux M900 Pro", False),
    0x73: ("Inphic IN10R MAX", False),
    0x74: ("Inphic IN10 MAX", False),
}

# Solaar Li-ion discharge curve for Logitech HID++ 0x1F20 ADC voltage (mV -> %)
LOGITECH_CURVE = (
    (4186, 100),
    (4067, 90),
    (3989, 80),
    (3922, 70),
    (3859, 60),
    (3811, 50),
    (3778, 40),
    (3751, 30),
    (3717, 20),
    (3671, 10),
    (3646, 5),
    (3579, 2),
    (3500, 0),
)

HEADSET_POLL_INTERVAL = 20.0
MOUSE_RESCAN_INTERVAL = 5.0
MOUSE_SLEEP_TIMEOUT = 90.0


def voltage_to_percent(mv: int) -> int:
    if mv >= LOGITECH_CURVE[0][0]:
        return 100
    for i in range(1, len(LOGITECH_CURVE)):
        hi_mv, hi_p = LOGITECH_CURVE[i - 1]
        lo_mv, lo_p = LOGITECH_CURVE[i]
        if mv >= lo_mv:
            return lo_p + (mv - lo_mv) * (hi_p - lo_p) // (hi_mv - lo_mv)
    return 0


def parse_hid_uevent(sys_dev_path: str) -> dict:
    info = {}
    try:
        with open(os.path.join(sys_dev_path, "uevent"), "r", encoding="utf-8", errors="ignore") as f:
            for line in f:
                if "=" in line:
                    k, v = line.strip().split("=", 1)
                    info[k] = v
    except OSError:
        return info

    hid_id = info.get("HID_ID", "")
    parts = hid_id.split(":")
    if len(parts) == 3:
        try:
            info["vid"] = int(parts[1], 16)
            info["pid"] = int(parts[2], 16)
        except ValueError:
            pass
    return info


def scan_hidraw() -> list:
    devices = []
    for sys_path in sorted(glob.glob("/sys/class/hidraw/hidraw*")):
        name = os.path.basename(sys_path)
        dev_path = f"/dev/{name}"
        dev_dir = os.path.join(sys_path, "device")
        info = parse_hid_uevent(dev_dir)
        if "vid" not in info or "pid" not in info:
            continue
        desc = b""
        try:
            with open(os.path.join(dev_dir, "report_descriptor"), "rb") as f:
                desc = f.read(512)
        except OSError:
            pass
        info["hidraw"] = dev_path
        info["descriptor"] = desc
        devices.append(info)
    return devices


def hidpp_xfer(fd: int, pkt: bytes, timeout: float = 0.4) -> bytes | None:
    while True:
        r, _, _ = select.select([fd], [], [], 0.01)
        if not r:
            break
        try:
            os.read(fd, 64)
        except OSError:
            break

    os.write(fd, pkt)
    deadline = time.monotonic() + timeout
    expected_feat = pkt[2]
    expected_sw = pkt[3] & 0x0F

    while True:
        rem = deadline - time.monotonic()
        if rem <= 0:
            return None
        r, _, _ = select.select([fd], [], [], rem)
        if not r:
            return None
        try:
            data = os.read(fd, 64)
        except OSError:
            return None
        if len(data) >= 7 and data[0] in (0x10, 0x11):
            if data[2] == expected_feat and (data[3] & 0x0F) == expected_sw:
                return data
            # HID++ 2.0 error report (0xFF)
            if data[2] == 0xFF and data[3] == expected_feat:
                return None


class HeadsetMonitor:
    def __init__(self):
        self.feature_cache: dict[str, tuple[int, int]] = {}
        self.state = {
            "name": "Logitech PRO X Wireless",
            "present": False,
            "online": False,
            "percent": -1,
            "charging": False,
            "voltage_mv": 0,
            "status": "not_found",
            "hidraw": "",
        }

    def poll(self, devices: list) -> dict:
        target = None
        for d in devices:
            if d["vid"] == LOGITECH_VID and d["pid"] in HEADSET_PIDS:
                target = d
                break

        if not target:
            self.feature_cache.clear()
            self.state = {
                "name": "Logitech PRO X Wireless",
                "present": False,
                "online": False,
                "percent": -1,
                "charging": False,
                "voltage_mv": 0,
                "status": "not_found",
                "hidraw": "",
            }
            return self.state

        hidraw = target["hidraw"]
        name = HEADSET_PIDS.get(target["pid"], target.get("HID_NAME", "Logitech Headset"))

        fd = None
        try:
            fd = os.open(hidraw, os.O_RDWR | os.O_NONBLOCK)
            cached = self.feature_cache.get(hidraw)
            if not cached:
                feat_idx = 0
                feat_id = 0
                for candidate in (0x1F20, 0x1004, 0x1000, 0x1001):
                    pkt = bytes([0x11, 0xFF, 0x00, 0x0A, (candidate >> 8) & 0xFF, candidate & 0xFF] + [0] * 14)
                    resp = hidpp_xfer(fd, pkt)
                    if resp and resp[4] != 0:
                        feat_idx = resp[4]
                        feat_id = candidate
                        break
                if feat_idx == 0:
                    self.state = {
                        "name": name,
                        "present": True,
                        "online": False,
                        "percent": -1,
                        "charging": False,
                        "voltage_mv": 0,
                        "status": "unsupported",
                        "hidraw": hidraw,
                    }
                    return self.state
                self.feature_cache[hidraw] = (feat_idx, feat_id)
                cached = (feat_idx, feat_id)

            feat_idx, feat_id = cached
            func_byte = 0x1A if feat_id == 0x1004 else 0x0A
            pkt = bytes([0x11, 0xFF, feat_idx, func_byte] + [0] * 16)
            resp = hidpp_xfer(fd, pkt)
            if not resp:
                self.state = {
                    "name": name,
                    "present": True,
                    "online": False,
                    "percent": -1,
                    "charging": False,
                    "voltage_mv": 0,
                    "status": "offline",
                    "hidraw": hidraw,
                }
                return self.state

            r = resp[4:]
            if feat_id == 0x1F20:
                mv = (r[0] << 8) | r[1]
                flags = r[2]
                online = bool(flags & 0x01)
                charging = bool(flags & 0x02)
                if online and mv > 0:
                    pct = voltage_to_percent(mv)
                    self.state = {
                        "name": name,
                        "present": True,
                        "online": True,
                        "percent": pct,
                        "charging": charging,
                        "voltage_mv": mv,
                        "status": "charging" if charging else "ok",
                        "hidraw": hidraw,
                    }
                else:
                    self.state = {
                        "name": name,
                        "present": True,
                        "online": False,
                        "percent": -1,
                        "charging": False,
                        "voltage_mv": 0,
                        "status": "offline",
                        "hidraw": hidraw,
                    }
            elif feat_id == 0x1004:
                pct = r[0] if r[0] > 0 else -1
                charging = r[2] in (1, 2, 4)
                self.state = {
                    "name": name,
                    "present": True,
                    "online": True,
                    "percent": pct,
                    "charging": charging,
                    "voltage_mv": 0,
                    "status": "charging" if charging else "ok",
                    "hidraw": hidraw,
                }
            elif feat_id == 0x1001:
                mv = (r[0] << 8) | r[1]
                charging = bool(r[2] & 0x80)
                pct = voltage_to_percent(mv)
                self.state = {
                    "name": name,
                    "present": True,
                    "online": True,
                    "percent": pct,
                    "charging": charging,
                    "voltage_mv": mv,
                    "status": "charging" if charging else "ok",
                    "hidraw": hidraw,
                }
            elif feat_id == 0x1000:
                pct = r[0] if r[0] > 0 else (100 if r[2] == 3 else -1)
                charging = r[2] in (1, 2, 4)
                self.state = {
                    "name": name,
                    "present": True,
                    "online": True,
                    "percent": pct,
                    "charging": charging,
                    "voltage_mv": 0,
                    "status": "charging" if charging else "ok",
                    "hidraw": hidraw,
                }
        except PermissionError:
            self.state = {
                "name": name,
                "present": True,
                "online": False,
                "percent": -1,
                "charging": False,
                "voltage_mv": 0,
                "status": "permission_denied",
                "hidraw": hidraw,
            }
        except OSError:
            self.feature_cache.pop(hidraw, None)
            self.state["online"] = False
            self.state["status"] = "offline"
        finally:
            if fd is not None:
                try:
                    os.close(fd)
                except OSError:
                    pass

        return self.state


class MouseMonitor:
    def __init__(self):
        self.fd: int | None = None
        self.hidraw: str = ""
        self.last_candidate: tuple[int, int, int] | None = None
        self.last_frame_time: float = 0.0
        self.state = {
            "name": "Souris 2.4G",
            "present": False,
            "online": False,
            "percent": -1,
            "charging": False,
            "wired": False,
            "sleeping": False,
            "status": "not_found",
            "hidraw": "",
        }

    def close(self):
        if self.fd is not None:
            try:
                os.close(self.fd)
            except OSError:
                pass
            self.fd = None

    def _is_status_interface(self, d: dict) -> bool:
        desc = d.get("descriptor", b"")
        # Usage Page 0x000A (05 0a) + Report ID 0x03 (85 03)
        if b"\x05\x0a" in desc and b"\x85\x03" in desc:
            return True
        # Fallback: FA65 vendor page 0xFF00 (06 00 ff) + Report ID 0x03
        if d["pid"] == 0xFA65 and b"\x06\x00\xff" in desc and b"\x85\x03" in desc:
            return True
        return False

    def ensure_open(self, devices: list) -> bool:
        # 1. Check wired Attack Shark USB PIDs first
        for d in devices:
            if d["vid"] == XENTA_VID and d["pid"] in MOUSE_WIRED_PIDS:
                self.close()
                changed = (
                    not self.state["wired"]
                    or not self.state["present"]
                    or self.state["status"] != "wired"
                )
                self.state = {
                    "name": MOUSE_WIRED_PIDS[d["pid"]],
                    "present": True,
                    "online": True,
                    "percent": self.state["percent"],
                    "charging": True,
                    "wired": True,
                    "sleeping": False,
                    "status": "wired",
                    "hidraw": d["hidraw"],
                }
                return changed

        # 2. Look for 2.4G receiver status interface
        target = None
        any_receiver = None
        for d in devices:
            if d["vid"] == XENTA_VID and d["pid"] in MOUSE_RECEIVER_PIDS:
                any_receiver = d
                if self._is_status_interface(d):
                    target = d
                    break

        if not target and not any_receiver:
            self.close()
            was_present = self.state["present"]
            self.state = {
                "name": "Souris 2.4G",
                "present": False,
                "online": False,
                "percent": -1,
                "charging": False,
                "wired": False,
                "sleeping": False,
                "status": "not_found",
                "hidraw": "",
            }
            return was_present

        target = target or any_receiver
        hidraw = target["hidraw"]

        # Already open on same path?
        if self.fd is not None and self.hidraw == hidraw and os.path.exists(hidraw):
            return False

        self.close()
        self.hidraw = hidraw
        try:
            self.fd = os.open(hidraw, os.O_RDONLY | os.O_NONBLOCK)
            prev_status = self.state["status"]
            self.state["present"] = True
            self.state["wired"] = False
            self.state["hidraw"] = hidraw
            if self.state["percent"] < 0:
                self.state["status"] = "waiting"
            return prev_status != self.state["status"] or not self.state["present"]
        except PermissionError:
            changed = self.state["status"] != "permission_denied" or not self.state["present"]
            self.state = {
                "name": self.state["name"] if self.state["name"] != "Souris 2.4G" else "Attack Shark 2.4G",
                "present": True,
                "online": False,
                "percent": -1,
                "charging": False,
                "wired": False,
                "sleeping": False,
                "status": "permission_denied",
                "hidraw": hidraw,
            }
            return changed
        except OSError:
            return False

    def handle_read(self) -> bool:
        if self.fd is None:
            return False
        changed = False
        while True:
            try:
                data = os.read(self.fd, 64)
            except BlockingIOError:
                break
            except OSError:
                self.close()
                self.state["online"] = False
                self.state["status"] = "disconnected"
                return True

            if not data:
                break
            if len(data) < 5 or data[0] != 0x03 or data[2] not in (0x40, 0x41):
                continue

            model_code = data[1]
            st = data[3]
            ll = data[4]
            self.last_frame_time = time.monotonic()

            model_info = XENTA_MODELS.get(model_code)
            if model_info:
                model_name, is_tens = model_info
            else:
                model_name = f"Souris 2.4G (0x{model_code:02X})"
                is_tens = False

            if is_tens:
                pct = max(0, min(100, ll * 10))
                charging = False
                cand = (model_code, 1, pct)
            else:
                if st in (0x02, 0x03):
                    # On cable or dock: firmware freezes level
                    charging = True
                    pct = self.state["percent"]
                    cand = (model_code, st, -1)
                elif st == 0x01 and 0 <= ll <= 100:
                    charging = False
                    pct = ll
                    cand = (model_code, st, pct)
                else:
                    continue

            # Ignore the single bogus 100% frame sent right on link-up until two frames agree
            if not charging and pct == 100 and self.last_candidate != cand:
                self.last_candidate = cand
                continue

            # For normal readings, also prefer confirming 2 frames if this is the very first reading
            if self.state["percent"] < 0 and not charging and self.last_candidate != cand:
                self.last_candidate = cand
                continue

            self.last_candidate = cand

            new_state = {
                "name": model_name,
                "present": True,
                "online": True,
                "percent": pct,
                "charging": charging,
                "wired": False,
                "sleeping": False,
                "status": "charging" if charging else "ok",
                "hidraw": self.hidraw,
            }
            if new_state != self.state:
                self.state = new_state
                changed = True

        return changed

    def check_sleep(self) -> bool:
        if (
            self.fd is not None
            and self.last_frame_time > 0
            and not self.state["sleeping"]
            and (time.monotonic() - self.last_frame_time) > MOUSE_SLEEP_TIMEOUT
        ):
            self.state["sleeping"] = True
            self.state["online"] = False
            self.state["status"] = "sleeping"
            return True
        return False


def emit(headset: dict, mouse: dict):
    payload = json.dumps({"headset": headset, "mouse": mouse}, separators=(",", ":"))
    try:
        sys.stdout.write(payload + "\n")
        sys.stdout.flush()
    except BrokenPipeError:
        sys.exit(0)


def main():
    once = "--once" in sys.argv
    running = True
    force_refresh = False

    def on_signal(signum, _frame):
        nonlocal running, force_refresh
        if signum == signal.SIGUSR1:
            force_refresh = True
        else:
            running = False

    signal.signal(signal.SIGTERM, on_signal)
    signal.signal(signal.SIGINT, on_signal)
    signal.signal(signal.SIGUSR1, on_signal)

    headset = HeadsetMonitor()
    mouse = MouseMonitor()

    devices = scan_hidraw()
    headset.poll(devices)
    mouse.ensure_open(devices)
    if once:
        # Wait up to 4.5s for passive mouse frames if fd is readable
        if mouse.fd is not None:
            end = time.monotonic() + 4.5
            while time.monotonic() < end and mouse.state["percent"] < 0 and not mouse.state["charging"]:
                r, _, _ = select.select([mouse.fd], [], [], max(0.05, end - time.monotonic()))
                if r:
                    mouse.handle_read()
        emit(headset.state, mouse.state)
        mouse.close()
        return

    emit(headset.state, mouse.state)
    last_sent = (dict(headset.state), dict(mouse.state))
    last_headset_poll = time.monotonic()
    last_mouse_scan = time.monotonic()

    stdin_fd = None
    try:
        fd0 = sys.stdin.fileno()
        if stat.S_ISFIFO(os.fstat(fd0).st_mode):
            stdin_fd = fd0
    except Exception:
        stdin_fd = None

    while running:
        now = time.monotonic()
        need_devices = False
        changed = False

        if force_refresh or (now - last_headset_poll) >= HEADSET_POLL_INTERVAL:
            need_devices = True

        if mouse.fd is None and (now - last_mouse_scan) >= MOUSE_RESCAN_INTERVAL:
            need_devices = True
        elif (now - last_mouse_scan) >= 15.0:
            # Periodic check for wired plug-in / unplug
            need_devices = True

        devices = scan_hidraw() if need_devices else []

        if force_refresh or (now - last_headset_poll) >= HEADSET_POLL_INTERVAL:
            headset.poll(devices)
            last_headset_poll = now
            if force_refresh:
                changed = True
            force_refresh = False

        if need_devices:
            if mouse.ensure_open(devices):
                changed = True
            last_mouse_scan = now

        if mouse.check_sleep():
            changed = True

        if changed or (headset.state, mouse.state) != last_sent:
            emit(headset.state, mouse.state)
            last_sent = (dict(headset.state), dict(mouse.state))

        watch_fds = []
        if mouse.fd is not None:
            watch_fds.append(mouse.fd)
        if stdin_fd is not None:
            watch_fds.append(stdin_fd)

        try:
            r, _, _ = select.select(watch_fds, [], [], 2.0)
        except InterruptedError:
            continue

        if mouse.fd is not None and mouse.fd in r:
            if mouse.handle_read():
                emit(headset.state, mouse.state)
                last_sent = (dict(headset.state), dict(mouse.state))

        if stdin_fd is not None and stdin_fd in r:
            try:
                chunk = os.read(stdin_fd, 256)
                if not chunk:
                    # Parent process closed stdin
                    break
                if b"refresh" in chunk:
                    force_refresh = True
            except OSError:
                stdin_fd = None

    mouse.close()


if __name__ == "__main__":
    main()
