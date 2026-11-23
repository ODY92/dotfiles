import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Services.Pipewire
import QtQuick
import "root:/overlays"
import "root:/panels"
import "root:/services"

ShellRoot {
    id: root

    property bool barEnabled: true

    Timer {
        id: fullscreenRefresh
        interval: 50
        onTriggered: {
            Hyprland.refreshMonitors();
            Hyprland.refreshWorkspaces();
            Hyprland.refreshToplevels();
        }
    }

    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (["fullscreen", "workspace", "workspacev2", "activespecial", "activespecialv2",
                 "focusedmon", "focusedmonv2", "movewindow", "movewindowv2",
                 "openwindow", "closewindow", "monitoradded", "monitorremoved"].includes(event.name))
                fullscreenRefresh.restart();
        }
    }

    Component.onCompleted: fullscreenRefresh.start()

    FileView {
        path: Quickshell.env("HOME") + "/.config/caelestia/bar-enabled"
        blockLoading: true
        watchChanges: true
        onFileChanged: reload()
        onLoaded: root.barEnabled = text().trim() !== "off"
    }

    PwObjectTracker {
        objects: [Pipewire.defaultAudioSink, Pipewire.defaultAudioSource].filter(node => node !== null)
    }

    LazyLoader {
        id: island
        active: !root.barEnabled
        Island {}
    }

    LazyLoader {
        id: settings
        IslandPanel {}
    }

    TahoeDock { id: dock }

    IpcHandler {
        target: "dock"
        function state(): string { return JSON.stringify({enabled: DockApps.enabled, pins: DockApps.pins, picker: dock.pickerOpen, menu: dock.menuApp?.id || "", search: dock.search, apps: DockApps.apps.map(app => ({id: app.id, name: app.name, pinned: app.pinned, windows: app.windows.length}))}); }
        function pin(id: string): bool { return DockApps.pin(id); }
        function unpin(id: string): void { DockApps.unpin(id); }
        function show(): void { DockApps.setEnabled(true); }
        function hide(): void { DockApps.setEnabled(false); }
        function picker(): void { dock.pickerOpen = true; }
        function close(): void { dock.closePanel(); }
    }

    IpcHandler {
        target: "bridge"

        function state(): string {
            return JSON.stringify({barEnabled: root.barEnabled, loaded: island.item !== null,
                kind: island.item ? island.item.kind : ""});
        }

        function notify(payload: string): void {
            if (!island.item)
                return;
            try {
                NotifHistory.add(JSON.parse(payload));
            } catch (error) {
                console.warn("Invalid notification payload: " + error);
            }
        }

        function configure(): void {
            settings.active = true;
            Qt.callLater(() => { if (settings.item) settings.item.toggle(); });
        }
    }
}
