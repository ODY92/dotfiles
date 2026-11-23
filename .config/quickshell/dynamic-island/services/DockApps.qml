pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Wayland

Singleton {
    id: root

    readonly property var pins: store.pins
    readonly property bool enabled: store.enabled
    property var icons: ({})

    function entry(id) {
        return DesktopEntries.byId(id) || DesktopEntries.heuristicLookup(id);
    }

    function key(id) {
        const app = root.entry(id);
        return app ? app.id : id;
    }

    function pinned(id) {
        return root.pins.indexOf(root.key(id)) !== -1;
    }

    function pin(id) {
        const app = root.entry(id);
        if (!app || root.pinned(app.id))
            return false;
        store.pins = root.pins.concat([app.id]);
        config.writeAdapter();
        return true;
    }

    function unpin(id) {
        store.pins = root.pins.filter(value => value !== root.key(id));
        config.writeAdapter();
    }

    function move(id, direction) {
        const next = root.pins.slice();
        const before = next.indexOf(root.key(id));
        const after = Math.max(0, Math.min(next.length - 1, before + direction));
        if (before < 0 || before === after)
            return;
        next.splice(after, 0, next.splice(before, 1)[0]);
        store.pins = next;
        config.writeAdapter();
    }

    function setEnabled(value) {
        store.enabled = value;
        config.writeAdapter();
    }

    function icon(id) {
        const app = root.entry(id);
        const aliases = { luma: "safari", thunar: "file-manager", chatgpt: "openai", codium: "vscodium" };
        const names = [aliases[id.toLowerCase()], app?.icon, app?.id, id];
        for (const name of names) {
            if (name && root.icons[name.toLowerCase()])
                return root.icons[name.toLowerCase()];
        }
        return root.icons["application-default-icon"] || Quickshell.iconPath("application-x-executable");
    }

    function fullscreen(screen) {
        const monitor = Hyprland.monitorFor(screen);
        const special = monitor?.lastIpcObject.specialWorkspace?.name;
        const workspace = special
            ? Hyprland.workspaces.values.find(value => value.name === special)
            : monitor?.activeWorkspace;
        return workspace?.toplevels.values.some(value => value.lastIpcObject.fullscreen > 1) ?? false;
    }

    readonly property var apps: {
        const output = [];
        const grouped = ({});
        for (const id of root.pins) {
            const app = root.entry(id);
            if (!app)
                continue;
            const item = { id: app.id, name: app.name, app: app, windows: [], pinned: true };
            grouped[app.id] = item;
            output.push(item);
        }
        for (const window of ToplevelManager.toplevels.values) {
            if (!window || !window.appId || !window.title.trim())
                continue;
            const app = root.entry(window.appId);
            const id = app ? app.id : window.appId;
            let item = grouped[id];
            if (!item) {
                item = { id: id, name: app?.name || window.appId, app: app, windows: [], pinned: false };
                grouped[id] = item;
                output.push(item);
            }
            item.windows.push(window);
        }
        return output;
    }

    function activate(item, newWindow) {
        if (!newWindow && item.windows.length > 0) {
            const current = item.windows.findIndex(window => window.activated);
            item.windows[(current + 1) % item.windows.length].activate();
        } else if (item.app) {
            item.app.execute();
        }
    }

    FileView {
        id: config
        path: Quickshell.env("HOME") + "/.config/caelestia/dock.json"
        blockLoading: true
        watchChanges: true
        onFileChanged: reload()
        onLoadFailed: error => {
            if (error === FileViewError.FileNotFound)
                writeAdapter();
        }
        JsonAdapter {
            id: store
            property bool enabled: true
            property var pins: ["thunar", "luma", "kitty", "codium", "discord", "steam"]
        }
    }

    FileView {
        path: Quickshell.env("HOME") + "/.config/quickshell/dynamic-island/dock-icons.json"
        blockLoading: true
        watchChanges: true
        onFileChanged: reload()
        onLoaded: root.icons = JSON.parse(text())
    }
}
