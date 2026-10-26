pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.components
import qs.services
import qs.modules.bar.popouts // Need to import this module so the Wrapper type is the same as others

Item {
    id: root

    required property ShellScreen screen
    required property real borderThickness
    property var bar

    readonly property alias content: content
    property real offsetScale: content.isDetached || content.hasCurrent ? 0 : 1

    readonly property string pos: BarPos.position
    readonly property bool horiz: BarPos.horizontal
    readonly property real barOffset: bar ? bar.floatMargin : 0
    readonly property real insetL: bar ? bar.insetL : 0
    readonly property real insetT: bar ? bar.insetT : borderThickness

    function clampPos(off: real, total: real, size: real): real {
        const diff = total - Math.floor(off + size);
        if (diff < 0)
            return off + diff;
        return Math.max(off, 0);
    }

    visible: width > 0 && height > 0
    clip: true

    implicitWidth: horiz ? content.implicitWidth : content.implicitWidth * (1 - offsetScale)
    implicitHeight: horiz ? content.implicitHeight * (1 - offsetScale) : content.implicitHeight

    x: {
        if (content.isDetached)
            return (parent.width - content.nonAnimWidth) / 2;
        if (horiz)
            return clampPos(content.currentCenter + barOffset - insetL - content.nonAnimWidth / 2, parent.width, content.nonAnimWidth);
        return pos === "right" ? parent.width - width : 0;
    }
    y: {
        if (content.isDetached)
            return (parent.height - content.nonAnimHeight) / 2;
        if (!horiz)
            return clampPos(content.currentCenter + barOffset - insetT - content.nonAnimHeight / 2, parent.height, content.nonAnimHeight);
        return pos === "bottom" ? parent.height - height : 0;
    }

    Behavior on offsetScale {
        Anim {}
    }

    Behavior on x {
        enabled: content.isDetached || (root.horiz ? root.offsetScale < 1 : root.pos === "left")

        Anim {
            duration: content.animLength
            easing: content.animCurve
        }
    }

    Behavior on y {
        enabled: (root.horiz ? content.isDetached : true) && root.offsetScale < 1

        Anim {
            duration: content.animLength
            easing: content.animCurve
        }
    }

    Wrapper {
        id: content

        screen: root.screen
        offsetScale: root.offsetScale

        anchors.verticalCenter: root.horiz ? undefined : parent.verticalCenter
        anchors.horizontalCenter: root.horiz ? parent.horizontalCenter : undefined
        anchors.left: root.pos === "left" ? parent.left : undefined
        anchors.right: root.pos === "right" ? parent.right : undefined
        anchors.top: root.pos === "top" ? parent.top : undefined
        anchors.bottom: root.pos === "bottom" ? parent.bottom : undefined
        anchors.leftMargin: (-implicitWidth - 5) * root.offsetScale
        anchors.rightMargin: (-implicitWidth - 5) * root.offsetScale
        anchors.topMargin: (-implicitHeight - 5) * root.offsetScale
        anchors.bottomMargin: (-implicitHeight - 5) * root.offsetScale
    }
}
