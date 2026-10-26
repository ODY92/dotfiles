pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Caelestia.Config
import qs.modules.bar as Bar

Region {
    id: root

    required property Bar.BarWrapper bar
    required property Panels panels
    required property var win

    readonly property real borderThickness: win.contentItem.Config.border.thickness
    readonly property real clampedThickness: win.contentItem.Config.border.clampedThickness

    x: bar.maskL + win.dragMaskPadding
    y: bar.maskT + win.dragMaskPadding
    width: win.width - bar.maskL - bar.maskR - win.dragMaskPadding * 2
    height: win.height - bar.maskT - bar.maskB - win.dragMaskPadding * 2
    intersection: Intersection.Xor

    R {
        panel: root.panels.dashboard
        y: 0
        height: panel.height * (1 - root.panels.dashboard.offsetScale) + root.bar.insetT
    }

    R {
        panel: root.panels.launcher
        y: root.win.height - height
        height: panel.height * (1 - root.panels.launcher.offsetScale) + root.bar.insetB
    }

    R {
        id: sessionRegion

        panel: root.panels.sessionWrapper
        x: root.win.width - width
        width: panel.width * (1 - root.panels.session.offsetScale) + root.bar.insetR + sidebarRegion.width
    }

    R {
        id: sidebarRegion

        panel: root.panels.sidebar
        x: root.win.width - width
        width: panel.width * (1 - root.panels.sidebar.offsetScale) + root.bar.insetR
    }

    R {
        panel: root.panels.osdWrapper
        x: root.win.width - width
        width: panel.width * (1 - root.panels.osd.offsetScale) + root.bar.insetR + sessionRegion.width
    }

    R {
        panel: root.panels.notifications
        y: 0
        height: panel.height + root.bar.insetT
    }

    R {
        panel: root.panels.utilities
        y: root.win.height - height
        height: panel.height * (1 - root.panels.utilities.offsetScale) + root.bar.insetB
    }

    R {
        panel: root.panels.popoutsWrapper
        width: panel.width * (1 - root.panels.popoutsWrapper.offsetScale)
    }

    component R: Region {
        required property Item panel

        x: panel.x + root.bar.insetL
        y: panel.y + root.bar.insetT
        width: panel.width
        height: panel.height
        intersection: Intersection.Subtract
    }
}
