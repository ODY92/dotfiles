pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    // left | right | top | bottom
    property string position: "left"
    readonly property bool horizontal: position === "top" || position === "bottom"

    function apply(raw: string): void {
        const p = (raw ?? "").trim();
        if (p === "left" || p === "right" || p === "top" || p === "bottom")
            position = p;
    }

    FileView {
        id: view
        path: Quickshell.env("HOME") + "/.config/caelestia/bar-position"
        blockLoading: true
        watchChanges: true
        onFileChanged: reload()
        onLoaded: root.apply(text())
    }

    Component.onCompleted: {
        try {
            root.apply(view.text());
        } catch (e) {}
    }
}
