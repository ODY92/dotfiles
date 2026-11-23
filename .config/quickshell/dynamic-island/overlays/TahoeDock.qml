import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Widgets
import "root:/services"

Scope {
    id: root

    property bool pickerOpen: false
    property var menuApp: null
    property string search: ""

    function closePanel() {
        root.pickerOpen = false;
        root.menuApp = null;
        root.search = "";
    }

    Variants {
        model: Quickshell.screens
        FloatingDockSurface { controller: root }
    }

    PanelWindow {
        id: panel
        screen: Hyprland.focusedMonitor ? Quickshell.screens.find(value => value.name === Hyprland.focusedMonitor.name) : Quickshell.screens[0]
        WlrLayershell.namespace: "tahoe-dock-menu"
        WlrLayershell.layer: WlrLayer.Overlay
        focusable: true
        anchors { top: true; bottom: true; left: true; right: true }
        exclusiveZone: -1
        color: "transparent"
        visible: DockApps.enabled && (root.pickerOpen || root.menuApp !== null)

        MouseArea {
            anchors.fill: parent
            onClicked: root.closePanel()
        }

        Rectangle {
            id: panelBody
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 150
            width: 390
            height: root.menuApp ? 310 : 490
            radius: 24
            color: "#c42a2d36"
            border.width: 1
            border.color: "#50ffffff"
            focus: true
            Keys.onEscapePressed: root.closePanel()

            MouseArea {
                anchors.fill: parent
                onClicked: mouse => mouse.accepted = true
            }

            Column {
                anchors.fill: parent
                anchors.margins: 18
                spacing: 12

                Row {
                    width: parent.width
                    Text {
                        width: parent.width - 30
                        text: root.menuApp ? root.menuApp.name : "Ajouter au dock"
                        color: "white"
                        font.pixelSize: 17
                        font.weight: Font.DemiBold
                        elide: Text.ElideRight
                    }
                    Text {
                        text: "×"
                        color: "#d0ffffff"
                        font.pixelSize: 22
                        MouseArea { anchors.fill: parent; onClicked: root.closePanel() }
                    }
                }

                Column {
                    width: parent.width
                    spacing: 4
                    visible: root.menuApp !== null
                    Repeater {
                        model: root.menuApp ? [
                            { label: DockApps.pinned(root.menuApp.id) ? "Retirer du dock" : "Épingler au dock", action: "pin" },
                            { label: "Ajouter une application…", action: "add" },
                            { label: "Ouvrir une nouvelle fenêtre", action: "open" },
                            { label: "Déplacer vers la gauche", action: "left" },
                            { label: "Déplacer vers la droite", action: "right" },
                            { label: "Fermer les fenêtres", action: "close" }
                        ] : []
                        Rectangle {
                            required property var modelData
                            width: parent.width
                            height: 34
                            radius: 8
                            color: actionMouse.containsMouse ? "#28ffffff" : "transparent"
                            Text { anchors.verticalCenter: parent.verticalCenter; x: 10; text: modelData.label; color: "white"; font.pixelSize: 13 }
                            MouseArea {
                                id: actionMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: {
                                    const item = root.menuApp;
                                    switch (modelData.action) {
                                    case "pin": DockApps.pinned(item.id) ? DockApps.unpin(item.id) : DockApps.pin(item.id); break;
                                    case "add": root.pickerOpen = true; root.menuApp = null; return;
                                    case "open": DockApps.activate(item, true); break;
                                    case "left": DockApps.move(item.id, -1); break;
                                    case "right": DockApps.move(item.id, 1); break;
                                    case "close": for (const window of item.windows) window.close(); break;
                                    }
                                    root.closePanel();
                                }
                            }
                        }
                    }
                }

                TextField {
                    id: search
                    width: parent.width
                    height: 42
                    visible: !root.menuApp
                    placeholderText: "Rechercher une application…"
                    color: "white"
                    placeholderTextColor: "#aab2c2"
                    font.pixelSize: 14
                    text: root.search
                    onTextEdited: root.search = text
                    background: Rectangle { radius: 12; color: "#30000000"; border.width: 1; border.color: "#30ffffff" }
                }

                ListView {
                    width: parent.width
                    height: 355
                    clip: true
                    spacing: 3
                    visible: !root.menuApp
                    model: DesktopEntries.applications.values.filter(app => !app.noDisplay && app.name.toLowerCase().includes(root.search.toLowerCase()))
                        .sort((first, second) => first.name.localeCompare(second.name))
                    delegate: Rectangle {
                        required property var modelData
                        width: ListView.view.width
                        height: 48
                        radius: 10
                        color: appMouse.containsMouse ? "#24ffffff" : "transparent"
                        IconImage { x: 9; anchors.verticalCenter: parent.verticalCenter; implicitSize: 34; source: DockApps.icon(modelData.id) }
                        Text { x: 54; anchors.verticalCenter: parent.verticalCenter; width: parent.width - 92; text: modelData.name; color: "white"; font.pixelSize: 13; elide: Text.ElideRight }
                        Text { anchors.right: parent.right; anchors.rightMargin: 12; anchors.verticalCenter: parent.verticalCenter; text: DockApps.pinned(modelData.id) ? "✓" : "+"; color: "white"; font.pixelSize: 21 }
                        MouseArea {
                            id: appMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: DockApps.pinned(modelData.id) ? DockApps.unpin(modelData.id) : DockApps.pin(modelData.id)
                        }
                    }
                }
            }
        }
        onVisibleChanged: if (visible && !root.menuApp) Qt.callLater(() => search.forceActiveFocus())
    }

}
