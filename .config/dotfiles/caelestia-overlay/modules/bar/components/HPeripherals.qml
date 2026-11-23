pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.services

StyledRect {
    id: root

    required property var bar
    property color colour: Colours.palette.m3secondary

    readonly property color headsetColour: {
        if (Peripherals.headsetOnline && !Peripherals.headsetCharging && Peripherals.headsetPercent >= 0 && Peripherals.headsetPercent <= 20)
            return Colours.palette.m3error;
        if (Peripherals.headsetCharging)
            return Colours.palette.m3primary;
        return root.colour;
    }

    readonly property color mouseColour: {
        if (Peripherals.mouseOnline && !Peripherals.mouseCharging && Peripherals.mousePercent >= 0 && Peripherals.mousePercent <= 20)
            return Colours.palette.m3error;
        if (Peripherals.mouseCharging || Peripherals.mouseWired)
            return Colours.palette.m3primary;
        return root.colour;
    }

    visible: Peripherals.hasAny
    color: Colours.tPalette.m3surfaceContainer
    radius: Tokens.rounding.full
    clip: true

    implicitHeight: Tokens.sizes.bar.innerWidth
    implicitWidth: visible ? layout.implicitWidth + Tokens.padding.medium * 2 : 0

    StateLayer {
        radius: Tokens.rounding.full
        onClicked: {
            const center = root.mapToItem(root.bar, root.implicitWidth / 2, 0).x;
            root.bar.popouts.toggleClickPopout("peripherals", center);
        }
    }

    RowLayout {
        id: layout

        anchors.centerIn: parent
        spacing: Tokens.spacing.small

        RowLayout {
            visible: Peripherals.headsetPresent
            spacing: Tokens.spacing.extraSmall
            opacity: Peripherals.headsetOnline ? 1 : 0.5

            MaterialIcon {
                Layout.alignment: Qt.AlignVCenter
                animate: true
                text: "headphones"
                color: root.headsetColour
                fontStyle: Tokens.font.icon.small
                fill: 1
            }

            MaterialIcon {
                Layout.alignment: Qt.AlignVCenter
                visible: Peripherals.headsetCharging
                text: "bolt"
                color: Colours.palette.m3primary
                fontStyle: Tokens.font.icon.builders.small.scale(0.85).build()
                fill: 1
            }

            StyledText {
                Layout.alignment: Qt.AlignVCenter
                text: Peripherals.headsetOnline && Peripherals.headsetPercent >= 0 ? `${Peripherals.headsetPercent}%` : "--"
                font: Tokens.font.body.builders.small.scale(0.95).build()
                color: root.headsetColour
            }
        }

        StyledRect {
            visible: Peripherals.headsetPresent && Peripherals.mousePresent
            Layout.alignment: Qt.AlignVCenter
            implicitWidth: 1
            implicitHeight: Math.round(Tokens.sizes.bar.innerWidth * 0.45)
            color: Colours.palette.m3outlineVariant
            opacity: 0.6
        }

        RowLayout {
            visible: Peripherals.mousePresent
            spacing: Tokens.spacing.extraSmall
            opacity: Peripherals.mouseOnline ? 1 : (Peripherals.mouseSleeping && Peripherals.mousePercent >= 0 ? 0.65 : 0.5)

            MaterialIcon {
                Layout.alignment: Qt.AlignVCenter
                animate: true
                text: "mouse"
                color: root.mouseColour
                fontStyle: Tokens.font.icon.small
                fill: 1
            }

            MaterialIcon {
                Layout.alignment: Qt.AlignVCenter
                visible: Peripherals.mouseCharging || Peripherals.mouseWired
                text: "bolt"
                color: Colours.palette.m3primary
                fontStyle: Tokens.font.icon.builders.small.scale(0.85).build()
                fill: 1
            }

            StyledText {
                Layout.alignment: Qt.AlignVCenter
                text: {
                    if (Peripherals.mousePercent >= 0)
                        return `${Peripherals.mousePercent}%`;
                    if (Peripherals.mouseCharging || Peripherals.mouseWired)
                        return "CHG";
                    return "--";
                }
                font: Tokens.font.body.builders.small.scale(0.95).build()
                color: root.mouseColour
            }
        }
    }
}
