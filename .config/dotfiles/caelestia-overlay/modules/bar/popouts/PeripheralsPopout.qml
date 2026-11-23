pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.services

ColumnLayout {
    id: root

    spacing: Tokens.spacing.medium
    implicitWidth: Math.max(260, Tokens.sizes.bar.batteryWidth)

    RowLayout {
        Layout.fillWidth: true
        spacing: Tokens.spacing.small

        StyledText {
            Layout.fillWidth: true
            text: qsTr("Périphériques")
            font: Tokens.font.body.builders.medium.weight(Font.Medium).build()
        }

        Item {
            implicitWidth: refreshIcon.implicitHeight + Tokens.padding.small
            implicitHeight: refreshIcon.implicitHeight + Tokens.padding.small

            StateLayer {
                radius: Tokens.rounding.full
                onClicked: Peripherals.refresh()
            }

            MaterialIcon {
                id: refreshIcon

                anchors.centerIn: parent
                text: "refresh"
                color: Colours.palette.m3onSurfaceVariant
            }
        }
    }

    DeviceCard {
        visible: Peripherals.headsetPresent
        icon: "headphones"
        name: Peripherals.headsetName
        percent: Peripherals.headsetOnline ? Peripherals.headsetPercent : -1
        charging: Peripherals.headsetCharging
        subtitle: {
            if (Peripherals.headsetStatus === "permission_denied")
                return qsTr("Accès %1 refusé").arg(Peripherals.headsetHidraw);
            if (!Peripherals.headsetOnline)
                return qsTr("Hors tension / hors portée");
            const stateStr = Peripherals.headsetCharging ? qsTr("En charge") : qsTr("Sur batterie");
            return Peripherals.headsetVoltageMv > 0 ? `${stateStr} · ${Peripherals.headsetVoltageMv} mV` : stateStr;
        }
    }

    DeviceCard {
        visible: Peripherals.mousePresent
        icon: "mouse"
        name: Peripherals.mouseName
        percent: Peripherals.mousePercent
        charging: Peripherals.mouseCharging || Peripherals.mouseWired
        subtitle: {
            if (Peripherals.mouseStatus === "permission_denied")
                return qsTr("Règle udev requise pour %1 (1d57:fa60)").arg(Peripherals.mouseHidraw);
            if (Peripherals.mouseWired)
                return qsTr("Branchée en USB (en charge)");
            if (Peripherals.mouseCharging)
                return qsTr("En charge");
            if (Peripherals.mouseSleeping)
                return qsTr("En veille · dernier niveau connu");
            if (Peripherals.mouseStatus === "waiting")
                return qsTr("En attente de signal 2.4 GHz…");
            if (!Peripherals.mouseOnline)
                return qsTr("Déconnectée");
            return qsTr("Sur batterie · 2.4 GHz");
        }
    }

    StyledText {
        visible: !Peripherals.hasAny
        text: qsTr("Aucun périphérique sans fil détecté")
        color: Colours.palette.m3onSurfaceVariant
    }

    component DeviceCard: StyledRect {
        id: card

        required property string icon
        required property string name
        required property int percent
        required property bool charging
        required property string subtitle

        readonly property bool low: !charging && percent >= 0 && percent <= 20
        readonly property color accent: low ? Colours.palette.m3error : Colours.palette.m3primary

        Layout.fillWidth: true
        implicitHeight: cardCol.implicitHeight + Tokens.padding.medium * 2
        radius: Tokens.rounding.large
        color: Colours.tPalette.m3surfaceContainer

        ColumnLayout {
            id: cardCol

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.margins: Tokens.padding.medium
            spacing: Tokens.spacing.small

            RowLayout {
                Layout.fillWidth: true
                spacing: Tokens.spacing.small

                MaterialIcon {
                    text: card.icon
                    color: card.accent
                    fontStyle: Tokens.font.icon.medium
                    fill: 1
                }

                StyledText {
                    Layout.fillWidth: true
                    text: card.name
                    elide: Text.ElideRight
                    font: Tokens.font.body.builders.small.weight(Font.Medium).build()
                }

                MaterialIcon {
                    visible: card.charging
                    text: "bolt"
                    color: Colours.palette.m3primary
                    fontStyle: Tokens.font.icon.small
                    fill: 1
                }

                StyledText {
                    text: card.percent >= 0 ? `${card.percent}%` : (card.charging ? "CHG" : "--")
                    color: card.accent
                    font: Tokens.font.mono.builders.medium.weight(Font.Medium).build()
                }
            }

            StyledProgressBar {
                Layout.fillWidth: true
                implicitHeight: 6
                value: card.percent >= 0 ? card.percent / 100 : 0
                fgColour: card.accent
                wavy: card.charging
                visible: card.percent >= 0
            }

            StyledText {
                Layout.fillWidth: true
                text: card.subtitle
                wrapMode: Text.Wrap
                color: Colours.palette.m3onSurfaceVariant
                font: Tokens.font.body.builders.small.scale(0.9).build()
            }
        }
    }
}
