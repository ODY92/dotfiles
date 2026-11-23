import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import Quickshell.Io
import "root:/services"

Scope {
    id: dock

    required property var modelData
    required property var controller
    readonly property bool fullscreen: DockApps.fullscreen(modelData)
    readonly property bool held: controller.pickerOpen || controller.menuApp !== null
    readonly property real slotWidth: Math.max(40, Math.min(76, (modelData.width - 200) / Math.max(1, DockApps.apps.length)))
    readonly property real baseWidth: DockApps.apps.length * slotWidth
    property bool revealed: true
    property real reveal: revealed || held ? 1 : 0

    IpcHandler {
        target: "dock-surface-" + dock.modelData.name
        function state(): string {
            return JSON.stringify({revealed: dock.revealed, reveal: dock.reveal,
                hovered: dockMouse.containsMouse, pointer: dockMouse.mouseX + dockMouse.x,
                width: shelf.width, iconSize: Math.min(64, dock.slotWidth - 12)});
        }
    }

    Behavior on reveal {
        NumberAnimation { duration: 240; easing.type: Easing.OutCubic }
    }

    onFullscreenChanged: {
        if (fullscreen) {
            controller.closePanel();
            revealed = false;
        }
    }

    onHeldChanged: {
        if (held) {
            hideDelay.stop();
            revealed = true;
        } else if (!dockMouse.containsMouse) {
            hideDelay.restart();
        }
    }

    Timer {
        id: hideDelay
        interval: 650
        running: true
        onTriggered: if (!dockMouse.containsMouse && !dock.held) dock.revealed = false
    }

    PanelWindow {
        id: win
        screen: dock.modelData
        WlrLayershell.namespace: "tahoe-dock"
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        anchors.bottom: true
        margins.bottom: Math.round(-112 * (1 - dock.reveal))
        implicitWidth: Math.min(dock.modelData.width - 24, dock.baseWidth + 152)
        implicitHeight: 200
        exclusiveZone: -1
        color: "transparent"
        visible: DockApps.enabled && !dock.fullscreen && dock.reveal > 0.001
        mask: Region { item: interactionArea }

        Item {
            id: interactionArea
            x: shelf.x - 12
            y: shelf.y - 72
            width: shelf.width + 24
            height: win.height - y
        }

        RectangularShadow {
            x: shelf.x
            y: shelf.y
            width: shelf.width
            height: shelf.height
            radius: 24
            blur: 50
            offset: Qt.vector2d(0, 5)
            color: Qt.rgba(0.03, 0.04, 0.08, 0.22)
        }

        Rectangle {
            id: shelf
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 12
            width: icons.implicitWidth + 24
            height: 88
            radius: 24
            color: "#01ffffff"

            Row {
                id: icons
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.verticalCenter: parent.verticalCenter
                spacing: 0

                Repeater {
                    id: apps
                    model: DockApps.apps

                    Item {
                        id: slot
                        required property var modelData
                        required property int index
                        readonly property real baseCenter: (win.width - dock.baseWidth) / 2
                            + index * (dock.slotWidth + icons.spacing) + dock.slotWidth / 2
                        readonly property real distance: dockMouse.containsMouse
                            ? Math.abs(dockMouse.mouseX + dockMouse.x - baseCenter) / dock.slotWidth : 10
                        width: dock.slotWidth
                        height: 88

                        IconImage {
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: 12
                            implicitSize: Math.min(64, dock.slotWidth - 12)
                            source: DockApps.icon(slot.modelData.id)
                        }

                        Rectangle {
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: 4
                            width: 4
                            height: 4
                            radius: 2
                            color: "#deefffff"
                            visible: slot.modelData.windows.length > 0
                        }

                        Rectangle {
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.bottom: parent.top
                            anchors.bottomMargin: 10
                            width: title.implicitWidth + 24
                            height: 29
                            radius: 10
                            color: "#d9222730"
                            border.width: 1
                            border.color: "#28ffffff"
                            opacity: slot.distance < 0.45 ? dock.reveal : 0
                            visible: opacity > 0.01
                            Behavior on opacity { NumberAnimation { duration: 130 } }
                            Text {
                                id: title
                                anchors.centerIn: parent
                                text: slot.modelData.name
                                color: "white"
                                font.pixelSize: 12
                            }
                        }
                    }
                }
            }
        }

        MouseArea {
            id: dockMouse
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
            onContainsMouseChanged: {
                if (containsMouse) {
                    hideDelay.stop();
                    dock.revealed = true;
                } else if (!dock.held) {
                    hideDelay.restart();
                }
            }
            onClicked: mouse => {
                const position = mouse.x + x - shelf.x - icons.x;
                let item = null;
                for (let index = 0; index < apps.count; index++) {
                    const slot = apps.itemAt(index);
                    if (position >= slot.x && position < slot.x + slot.width) {
                        item = slot.modelData;
                        break;
                    }
                }
                if (mouse.button === Qt.RightButton) {
                    dock.controller.menuApp = item;
                    dock.controller.pickerOpen = item === null;
                } else if (item) {
                    DockApps.activate(item, mouse.button === Qt.MiddleButton || (mouse.modifiers & Qt.ShiftModifier));
                }
            }
        }
    }

    PanelWindow {
        screen: dock.modelData
        WlrLayershell.namespace: "tahoe-dock-trigger"
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        anchors.bottom: true
        implicitWidth: Math.min(dock.modelData.width, dock.baseWidth + 100)
        implicitHeight: 3
        exclusiveZone: -1
        color: "transparent"
        visible: DockApps.enabled && !dock.fullscreen && !dock.revealed && !dock.held

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            onEntered: revealDelay.restart()
            onExited: revealDelay.stop()
        }

        Timer {
            id: revealDelay
            interval: 100
            onTriggered: dock.revealed = true
        }
    }
}
