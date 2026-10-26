import QtQuick
import Caelestia.Config
import qs.components
import qs.services
import qs.utils

Item {
    id: root

    required property var bar
    property color colour: Colours.palette.m3primary

    readonly property string windowTitle: {
        const title = Hypr.activeToplevel?.title;
        if (!title)
            return qsTr("Desktop");
        if (Config.bar.activeWindow.compact) {
            // " - " (standard hyphen), " — " (em dash), " – " (en dash)
            const parts = title.split(/\s+[\-\u2013\u2014]\s+/);
            if (parts.length > 1)
                return parts[parts.length - 1].trim();
        }
        return title;
    }

    readonly property int maxWidth: 420

    implicitHeight: Math.max(icon.implicitHeight, label.implicitHeight)
    implicitWidth: Math.min(maxWidth, icon.implicitWidth + Tokens.spacing.small + label.implicitWidth)

    Loader {
        asynchronous: true
        anchors.fill: parent
        active: !Config.bar.activeWindow.showOnHover

        sourceComponent: MouseArea {
            cursorShape: Qt.PointingHandCursor
            hoverEnabled: true
            onPositionChanged: {
                const popouts = root.bar.popouts;
                if (popouts.hasCurrent && popouts.currentName !== "activewindow")
                    popouts.hasCurrent = false;
            }
            onClicked: {
                const popouts = root.bar.popouts;
                if (popouts.hasCurrent) {
                    popouts.hasCurrent = false;
                } else {
                    popouts.currentName = "activewindow";
                    popouts.currentCenter = root.mapToItem(root.bar, root.implicitWidth / 2, 0).x;
                    popouts.hasCurrent = true;
                }
            }
        }
    }

    MaterialIcon {
        id: icon

        anchors.verticalCenter: parent.verticalCenter
        anchors.left: parent.left

        animate: true
        text: Icons.getAppCategoryIcon(Hypr.activeToplevel?.lastIpcObject.class, "desktop_windows")
        color: root.colour
    }

    StyledText {
        id: label

        anchors.verticalCenter: parent.verticalCenter
        anchors.left: icon.right
        anchors.leftMargin: Tokens.spacing.small

        width: Math.max(0, root.width - icon.implicitWidth - Tokens.spacing.small)
        text: root.windowTitle
        elide: Text.ElideRight
        font: Tokens.font.body.builders.small.letterSpacing(1.4).build()
        color: root.colour
    }
}
