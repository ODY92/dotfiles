pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Services.SystemTray
import Caelestia.Config
import qs.components.effects
import qs.services
import qs.utils

MouseArea {
    id: root

    required property SystemTrayItem modelData
    required property int index
    property var bar: null
    property bool horizontal: false

    acceptedButtons: Qt.LeftButton | Qt.RightButton
    cursorShape: Qt.PointingHandCursor
    implicitWidth: Tokens.font.body.small.pointSize * 2
    implicitHeight: Tokens.font.body.small.pointSize * 2

    function openMenu(): void {
        if (!bar || !modelData.hasMenu)
            return;
        const center = horizontal ? root.mapToItem(bar, root.implicitWidth / 2, 0).x : root.mapToItem(bar, 0, root.implicitHeight / 2).y;
        bar.popouts.toggleClickPopout(`traymenu${index}`, center);
    }

    onClicked: event => {
        if (event.button === Qt.LeftButton) {
            if (modelData.onlyMenu && modelData.hasMenu && bar)
                openMenu();
            else
                modelData.activate();
        } else {
            if (modelData.hasMenu && bar)
                openMenu();
            else
                modelData.secondaryActivate();
        }
    }

    ColouredIcon {
        id: icon

        anchors.fill: parent
        source: Icons.getTrayIcon(root.modelData.id, root.modelData.icon)
        colour: Colours.palette.m3secondary
        layer.enabled: Config.bar.tray.recolour
    }
}
