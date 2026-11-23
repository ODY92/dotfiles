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

    implicitWidth: Tokens.sizes.bar.innerWidth
    implicitHeight: visible ? layout.implicitHeight + Tokens.padding.medium * 2 : 0

    StateLayer {
        radius: Tokens.rounding.full
        onClicked: {
            const center = root.mapToItem(root.bar, 0, root.implicitHeight / 2).y;
            root.bar.popouts.toggleClickPopout("peripherals", center);
        }
    }

    ColumnLayout {
        id: layout

        anchors.centerIn: parent
        spacing: Tokens.spacing.small

        ColumnLayout {
            visible: Peripherals.headsetPresent
            Layout.alignment: Qt.AlignHCenter
            spacing: 0
            opacity: Peripherals.headsetOnline ? 1 : 0.5

            MaterialIcon {
                Layout.alignment: Qt.AlignHCenter
                animate: true
                text: Peripherals.headsetCharging ? "bolt" : "headphones"
                color: root.headsetColour
                fontStyle: Tokens.font.icon.small
                fill: 1
            }

            StyledText {
                Layout.alignment: Qt.AlignHCenter
                text: Peripherals.headsetOnline && Peripherals.headsetPercent >= 0 ? `${Peripherals.headsetPercent}%` : "--"
                font: Tokens.font.body.builders.small.scale(0.75).build()
                color: root.headsetColour
            }
        }

        StyledRect {
            visible: Peripherals.headsetPresent && Peripherals.mousePresent
            Layout.alignment: Qt.AlignHCenter
            implicitWidth: Math.round(Tokens.sizes.bar.innerWidth * 0.55)
            implicitHeight: 1
            color: Colours.palette.m3outlineVariant
            opacity: 0.6
        }

        ColumnLayout {
            visible: Peripherals.mousePresent
            Layout.alignment: Qt.AlignHCenter
            spacing: 0
            opacity: Peripherals.mouseOnline ? 1 : (Peripherals.mouseSleeping && Peripherals.mousePercent >= 0 ? 0.65 : 0.5)

            MaterialIcon {
                Layout.alignment: Qt.AlignHCenter
                animate: true
                text: (Peripherals.mouseCharging || Peripherals.mouseWired) ? "bolt" : "mouse"
                color: root.mouseColour
                fontStyle: Tokens.font.icon.small
                fill: 1
            }

            StyledText {
                Layout.alignment: Qt.AlignHCenter
                text: {
                    if (Peripherals.mousePercent >= 0)
                        return `${Peripherals.mousePercent}%`;
                    if (Peripherals.mouseCharging || Peripherals.mouseWired)
                        return "CHG";
                    return "--";
                }
                font: Tokens.font.body.builders.small.scale(0.75).build()
                color: root.mouseColour
            }
        }
    }
}
