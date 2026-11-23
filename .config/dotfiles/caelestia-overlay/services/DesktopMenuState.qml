pragma Singleton

import QtQuick
import Quickshell

Singleton {
    id: root

    property bool open: false
    property ShellScreen activeScreen: null
    property real anchorX: 0
    property real anchorY: 0
    property int openCounter: 0

    function openAt(screen: ShellScreen, x: real, y: real): void {
        activeScreen = screen;
        anchorX = x;
        anchorY = y;
        openCounter += 1;
        open = true;
    }

    function close(): void {
        open = false;
    }

    function toggle(screen: ShellScreen, x: real, y: real): void {
        if (open && activeScreen === screen) {
            close();
        } else {
            openAt(screen, x, y);
        }
    }
}
