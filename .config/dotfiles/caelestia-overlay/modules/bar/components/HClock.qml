pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.services

StyledRect {
    id: root

    readonly property color colour: Colours.palette.m3tertiary
    readonly property int padding: Config.bar.clock.background ? Tokens.padding.medium : Tokens.padding.extraSmall

    implicitHeight: Tokens.sizes.bar.innerWidth
    implicitWidth: layout.implicitWidth + padding * 2

    color: Qt.alpha(Colours.tPalette.m3surfaceContainer, Config.bar.clock.background ? Colours.tPalette.m3surfaceContainer.a : 0)
    radius: Tokens.rounding.full

    RowLayout {
        id: layout

        anchors.centerIn: parent
        spacing: Tokens.spacing.small

        StyledText {
            visible: Config.bar.clock.showDate
            text: Time.format("ddd d")
            font: Tokens.font.body.builders.small.scale(0.95).build()
            color: root.colour
        }

        StyledText {
            text: Time.hourStr + ":" + Time.minuteStr + (GlobalConfig.services.useTwelveHourClock ? " " + Time.amPmStr.toLowerCase() : "")
            font: Tokens.font.body.builders.small.scale(1.1).build()
            color: root.colour
        }
    }
}
