pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Caelestia.Config
import qs.components
import qs.services
import qs.utils
import qs.modules.bar.components.status

StyledRect {
    id: root

    property var bar: null
    property color colour: Colours.palette.m3secondary
    readonly property alias items: iconRow

    readonly property int spacing: Tokens.spacing.medium

    color: Colours.tPalette.m3surfaceContainer
    radius: Tokens.rounding.full

    clip: true
    implicitHeight: Tokens.sizes.bar.innerWidth
    implicitWidth: iconRow.implicitWidth + Tokens.padding.medium * 2

    RowLayout {
        id: iconRow

        anchors.centerIn: parent
        spacing: root.spacing

        Repeater {
            model: ScriptModel {
                values: root.Config.bar.statusIcons.elements.filter(e => e.enabled && e.id !== "lockStatus")
            }

            DelegateChooser {
                role: "id"

                DelegateChoice {
                    roleValue: "audio"
                    delegate: EntryWrapper {
                        MaterialIcon {
                            animate: true
                            text: Icons.getVolumeIcon(Audio.volume, Audio.muted)
                            color: root.colour
                            fontStyle: Tokens.font.icon.medium
                            fill: 1
                        }
                    }
                }
                DelegateChoice {
                    roleValue: "microphone"
                    delegate: EntryWrapper {
                        name: "audio" // Mic opens audio popout

                        MaterialIcon {
                            animate: true
                            text: Icons.getMicVolumeIcon(Audio.sourceVolume, Audio.sourceMuted)
                            color: root.colour
                            fontStyle: Tokens.font.icon.medium
                            fill: 1
                        }
                    }
                }
                DelegateChoice {
                    roleValue: "kbLayout"
                    delegate: EntryWrapper {
                        StyledText {
                            animate: true
                            text: Hypr.kbLayout
                            color: root.colour
                            font: Tokens.font.mono.medium
                        }
                    }
                }
                DelegateChoice {
                    roleValue: "network"
                    delegate: EntryWrapper {
                        MaterialIcon {
                            animate: true
                            text: Nmcli.activeEthernet ? "cable" : Nmcli.active ? Icons.getNetworkIcon(Nmcli.active.strength ?? 0) : "wifi_off"
                            color: root.colour
                        }
                    }
                }
                DelegateChoice {
                    roleValue: "bluetooth"
                    delegate: EntryWrapper {
                        BluetoothStatus {
                            colour: root.colour
                        }
                    }
                }
                DelegateChoice {
                    roleValue: "battery"
                    delegate: EntryWrapper {
                        BatteryStatus {
                            colour: root.colour
                        }
                    }
                }
            }
        }
    }

    component EntryWrapper: Item {
        id: wrapper

        required property var modelData
        required property int index
        default property Item item
        property string name: modelData.id.toLowerCase()

        Layout.alignment: Qt.AlignVCenter

        implicitWidth: item?.implicitWidth ?? 0
        implicitHeight: item?.implicitHeight ?? 0

        Item {
            anchors.fill: parent
            children: wrapper.item ? [wrapper.item] : []
        }

        StateLayer {
            anchors.fill: undefined
            anchors.centerIn: parent
            implicitWidth: Math.max(wrapper.implicitWidth + Tokens.padding.small, Tokens.sizes.bar.innerWidth - 4)
            implicitHeight: Tokens.sizes.bar.innerWidth - 4
            radius: Tokens.rounding.full
            onClicked: {
                if (!root.bar?.popouts)
                    return;
                const center = wrapper.mapToItem(root.bar, wrapper.implicitWidth / 2, 0).x;
                root.bar.popouts.toggleClickPopout(wrapper.name, center);
            }
        }
    }
}
