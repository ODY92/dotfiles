pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Caelestia.Config
import qs.components
import qs.services
import qs.utils
import qs.modules.bar.popouts as BarPopouts

Item {
    id: root

    required property ShellScreen screen
    required property ScreenState screenState
    required property BarPopouts.Wrapper popouts
    required property bool fullscreen

    readonly property bool disabled: !BarPos.enabled || Strings.testRegexList(Config.bar.excludedScreens, screen.name)

    readonly property string position: BarPos.position
    readonly property bool horizontal: BarPos.horizontal

    readonly property int padding: Math.max(Tokens.padding.small, Config.border.thickness)
    readonly property int floatMargin: Config.border.thickness + 12
    readonly property real pillRadius: 28
    readonly property int pillThick: Tokens.sizes.bar.innerWidth + padding * 2
    readonly property int contentExtent: floatMargin + pillThick + Config.border.thickness
    readonly property int exclusiveZone: !disabled && (Config.bar.persistent || screenState.bar) ? contentExtent : Config.border.thickness
    readonly property bool shouldBeVisible: !fullscreen && !disabled && (Config.bar.persistent || screenState.bar || isHovered)
    property bool isHovered

    // Épaisseur animée de la zone occupée par la barre (perpendiculaire à son bord)
    property real thick: fullscreen ? 0 : Config.border.thickness
    readonly property real clampedExtent: Math.max(Config.border.minThickness, thick)

    // Marge occupée de chaque côté de l'écran
    readonly property real baseInset: fullscreen ? 0 : Config.border.thickness
    readonly property real insetL: position === "left" ? thick : baseInset
    readonly property real insetR: position === "right" ? thick : baseInset
    readonly property real insetT: position === "top" ? thick : baseInset
    readonly property real insetB: position === "bottom" ? thick : baseInset

    // Même chose pour le masque de saisie
    readonly property real baseMask: Config.border.clampedThickness
    readonly property real maskL: position === "left" ? clampedExtent : baseMask
    readonly property real maskR: position === "right" ? clampedExtent : baseMask
    readonly property real maskT: position === "top" ? clampedExtent : baseMask
    readonly property real maskB: position === "bottom" ? clampedExtent : baseMask

    // Géométrie de la pilule dans ce wrapper
    readonly property real pillX: position === "right" ? width - floatMargin - pillThick : floatMargin
    readonly property real pillY: position === "bottom" ? height - floatMargin - pillThick : floatMargin
    readonly property real pillW: horizontal ? Math.max(0, width - floatMargin * 2) : pillThick
    readonly property real pillH: horizontal ? pillThick : Math.max(0, height - floatMargin * 2)

    function inBar(px: real, py: real): bool {
        if (disabled)
            return false;
        switch (position) {
        case "left":
            return px < clampedExtent;
        case "right":
            return px > parent.width - clampedExtent;
        case "top":
            return py < clampedExtent;
        default:
            return py > parent.height - clampedExtent;
        }
    }

    function along(px: real, py: real): real {
        return horizontal ? px : py;
    }

    function closeTray(): void {
        if (content.item)
            content.item.closeTray();
    }

    function checkPopout(pos: real): void {
        if (content.item)
            content.item.checkPopout(pos - floatMargin);
    }

    function handleWheel(pos: real, angleDelta: point): void {
        if (content.item)
            content.item.handleWheel(pos - floatMargin, angleDelta);
    }

    onDisabledChanged: {
        if (disabled) {
            isHovered = false;
            popouts.hasCurrent = false;
            closeTray();
        }
    }

    clip: true
    visible: thick > Config.border.thickness
    implicitWidth: horizontal ? 0 : thick
    implicitHeight: horizontal ? thick : 0

    states: State {
        name: "visible"
        when: root.shouldBeVisible

        PropertyChanges {
            root.thick: root.contentExtent
        }
    }

    transitions: [
        Transition {
            from: ""
            to: "visible"

            Anim {
                target: root
                property: "thick"
            }
        },
        Transition {
            from: "visible"
            to: ""

            Anim {
                target: root
                property: "thick"
                type: Anim.Emphasized
            }
        }
    ]

    // ---- Verre sombre ----
    Item {
        id: glass

        x: root.pillX
        y: root.pillY
        width: root.pillW
        height: root.pillH

        readonly property real r: Math.min(Math.min(width, height) / 2, root.pillRadius)

        // Liseré sombre extérieur
        Rectangle {
            anchors.fill: parent
            radius: glass.r
            color: "transparent"
            border.width: 1
            border.color: Qt.rgba(0, 0, 0, 0.40)
        }

        // Corps de verre : bleu nuit translucide
        Rectangle {
            anchors.fill: parent
            anchors.margins: 1
            radius: glass.r - 1
            color: Qt.rgba(0.06, 0.08, 0.13, 0.45)
        }

        // Reflet discret
        Rectangle {
            anchors.fill: parent
            anchors.margins: 1
            radius: glass.r - 1

            gradient: Gradient {
                GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, 0.16) }
                GradientStop { position: 0.12; color: Qt.rgba(1, 1, 1, 0.05) }
                GradientStop { position: 0.88; color: Qt.rgba(1, 1, 1, 0.02) }
                GradientStop { position: 1.0; color: Qt.rgba(1, 1, 1, 0.09) }
            }
        }

        // Bord clair fin
        Rectangle {
            anchors.fill: parent
            anchors.margins: 1
            radius: glass.r - 1
            color: "transparent"
            border.width: 1
            border.color: Qt.rgba(1, 1, 1, 0.30)
        }

        // Liseré intérieur
        Rectangle {
            anchors.fill: parent
            anchors.margins: 2
            radius: glass.r - 2
            color: "transparent"
            border.width: 1
            border.color: Qt.rgba(1, 1, 1, 0.10)
        }

        // Éclat lumineux en haut
        Rectangle {
            width: Math.min(glass.width * 0.6, 240)
            x: (glass.width - width) / 2
            y: 3
            height: 2
            radius: 1

            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, 0.0) }
                GradientStop { position: 0.5; color: Qt.rgba(1, 1, 1, 0.55) }
                GradientStop { position: 1.0; color: Qt.rgba(1, 1, 1, 0.0) }
            }
        }
    }

    Loader {
        id: content

        x: root.pillX
        y: root.pillY
        width: root.pillW
        height: root.pillH

        active: root.shouldBeVisible
        sourceComponent: root.horizontal ? hBar : vBar
    }

    Component {
        id: vBar

        Bar {
            screen: root.screen
            screenState: root.screenState
            popouts: root.popouts // qmllint disable incompatible-type
            fullscreen: root.fullscreen
        }
    }

    Component {
        id: hBar

        HBar {
            screen: root.screen
            screenState: root.screenState
            popouts: root.popouts // qmllint disable incompatible-type
            fullscreen: root.fullscreen
        }
    }
}
