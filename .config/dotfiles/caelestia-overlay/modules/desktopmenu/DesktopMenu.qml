pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import Caelestia
import Caelestia.Config
import qs.components
import qs.components.containers
import qs.modules.nexus
import qs.services

Scope {
    id: scopeRoot

    function findActiveScreen(): ShellScreen {
        const mon = Hypr.focusedMonitor;
        if (mon) {
            for (const s of Screens.screens) {
                if (Hypr.monitorFor(s) === mon)
                    return s;
            }
        }
        return Screens.screens[0] ?? null;
    }

    function createDesktopItem(isDir: bool): void {
        const script = isDir
            ? `dir="$HOME/Bureau"; mkdir -p "$dir"; base="Nouveau dossier"; name="$base"; i=2; while [ -e "$dir/$name" ]; do name="$base $i"; i=$((i+1)); done; mkdir -p "$dir/$name"; echo "$name"`
            : `dir="$HOME/Bureau"; mkdir -p "$dir"; base="Nouveau document"; name="$base.txt"; i=2; while [ -e "$dir/$name" ]; do name="$base $i.txt"; i=$((i+1)); done; : > "$dir/$name"; echo "$name"`;
        Quickshell.execDetached(["sh", "-c", script]);
        Toaster.toast(
            isDir ? "Nouveau dossier" : "Nouveau fichier",
            isDir ? "Dossier créé dans ~/Bureau" : "Fichier texte créé dans ~/Bureau",
            isDir ? "create_new_folder" : "description",
            Toast.Success
        );
    }

    function runAction(actionId: string, screen: ShellScreen): void {
        DesktopMenuState.close();

        switch (actionId) {
        case "antigravity":
            Quickshell.execDetached(["/usr/bin/antigravity"]);
            break;
        case "terminal":
            Quickshell.execDetached(["kitty"]);
            break;
        case "terminal_desktop":
            Quickshell.execDetached(["kitty", "--directory", Quickshell.env("HOME") + "/Bureau"]);
            break;
        case "open_desktop":
            Quickshell.execDetached(["thunar", Quickshell.env("HOME") + "/Bureau"]);
            break;
        case "new_folder":
            createDesktopItem(true);
            break;
        case "new_file":
            createDesktopItem(false);
            break;
        case "refresh":
            Quickshell.execDetached(["hyprctl", "reload"]);
            Toaster.toast("Bureau actualisé", "Configuration Hyprland rechargée", "refresh", Toast.Info);
            break;
        case "wallpaper":
            Quickshell.execDetached(["sh", "-c", "$HOME/.local/bin/wp-picker-toggle"]);
            break;
        case "toggle_theme":
            Colours.setMode(Colours.light ? "dark" : "light");
            break;
        case "display_settings":
            Quickshell.execDetached(["hyprmoncfg"]);
            break;
        case "shell_settings":
            WindowFactory.create();
            break;
        case "launcher": {
            const s = ShellState.forScreen(screen) ?? ShellState.forActive();
            if (s)
                s.launcher = true;
            break;
        }
        case "screenshot_region":
            Quickshell.execDetached(["hyprctl", "dispatch", "global", "caelestia:screenshotFreeze"]);
            break;
        case "screenshot_full":
            Quickshell.execDetached(["caelestia", "screenshot"]);
            break;
        case "color_picker":
            Quickshell.execDetached(["hyprpicker", "-a"]);
            break;
        case "save_clip":
            Quickshell.execDetached(["sh", "-c", "$HOME/.local/bin/clip.sh save"]);
            break;
        case "clipboard":
            Quickshell.execDetached(["sh", "-c", "pkill fuzzel || caelestia clipboard"]);
            break;
        case "lock":
            Quickshell.execDetached(["hyprctl", "dispatch", "global", "caelestia:lock"]);
            break;
        case "session_drawer": {
            const s = ShellState.forScreen(screen) ?? ShellState.forActive();
            if (s)
                s.session = true;
            break;
        }
        case "suspend":
            Quickshell.execDetached(["systemctl", "suspend-then-hibernate"]);
            break;
        case "reboot":
            Quickshell.execDetached(["systemctl", "reboot"]);
            break;
        case "poweroff":
            Quickshell.execDetached(["systemctl", "poweroff"]);
            break;
        }
    }

    IpcHandler {
        target: "desktopMenu"

        function openAt(x: real, y: real): void {
            const screen = scopeRoot.findActiveScreen();
            if (screen)
                DesktopMenuState.openAt(screen, x, y);
        }

        function toggle(): void {
            const screen = scopeRoot.findActiveScreen();
            if (screen)
                DesktopMenuState.toggle(screen, screen.width / 2, screen.height / 2);
        }

        function close(): void {
            DesktopMenuState.close();
        }
    }

    Variants {
        model: Screens.screens

        StyledWindow {
            id: win

            required property ShellScreen modelData

            readonly property bool isOpen: DesktopMenuState.open && DesktopMenuState.activeScreen === win.modelData
            property bool keepVisible: false
            property int activeIndex: -1
            property int openSubmenuIndex: -1
            property int subActiveIndex: -1
            property real submenuTriggerY: 0

            readonly property var menuItems: [
                { id: "antigravity", label: "Antigravity", svgIcon: "../../assets/gemini-logo.svg" },
                { separator: true },
                { id: "terminal", label: "Ouvrir un terminal", icon: "terminal", shortcut: "Super+T" },
                { id: "open_desktop", label: "Ouvrir le Bureau", icon: "folder_open", shortcut: "Super+E" },
                {
                    id: "new_sub",
                    label: "Nouveau",
                    icon: "add_circle",
                    children: [
                        { id: "new_folder", label: "Nouveau dossier", icon: "create_new_folder" },
                        { id: "new_file", label: "Nouveau fichier texte", icon: "description" },
                        { separator: true },
                        { id: "terminal_desktop", label: "Terminal dans le Bureau", icon: "terminal" }
                    ]
                },
                { id: "refresh", label: "Actualiser", icon: "refresh" },
                { separator: true },
                { id: "wallpaper", label: "Fond d'écran", icon: "wallpaper", shortcut: "Super+)" },
                { id: "toggle_theme", label: Colours.light ? "Passer en mode sombre" : "Passer en mode clair", icon: Colours.light ? "dark_mode" : "light_mode" },
                { id: "display_settings", label: "Paramètres d'affichage", icon: "monitor" },
                { id: "shell_settings", label: "Paramètres du shell", icon: "tune" },
                { separator: true },
                {
                    id: "tools_sub",
                    label: "Capture & Outils",
                    icon: "screenshot_region",
                    children: [
                        { id: "screenshot_region", label: "Capture de zone", icon: "crop", shortcut: "Super+⇧+S" },
                        { id: "screenshot_full", label: "Capture plein écran", icon: "screenshot_monitor", shortcut: "Impr" },
                        { id: "color_picker", label: "Pipette de couleur", icon: "colorize", shortcut: "Super+⇧+C" },
                        { separator: true },
                        { id: "save_clip", label: "Sauver le clip (30s)", icon: "movie", shortcut: "Super+G" },
                        { id: "clipboard", label: "Presse-papiers", icon: "content_paste", shortcut: "Super+V" }
                    ]
                },
                { id: "launcher", label: "Applications", icon: "apps", shortcut: "Super" },
                { separator: true },
                { id: "lock", label: "Verrouiller l'écran", icon: "lock", shortcut: "Super+L" },
                {
                    id: "power_sub",
                    label: "Alimentation",
                    icon: "power_settings_new",
                    children: [
                        { id: "session_drawer", label: "Menu de session", icon: "logout" },
                        { id: "suspend", label: "Mettre en veille", icon: "bedtime" },
                        { id: "reboot", label: "Redémarrer", icon: "restart_alt" },
                        { separator: true },
                        { id: "poweroff", label: "Éteindre", icon: "power_settings_new", danger: true }
                    ]
                }
            ]

            readonly property var activeSubmenuItems: {
                if (openSubmenuIndex < 0 || openSubmenuIndex >= menuItems.length)
                    return [];
                return menuItems[openSubmenuIndex].children ?? [];
            }

            readonly property real edgeMargin: 12
            readonly property real menuWidth: 312
            readonly property real subMenuWidth: 278

            readonly property bool flipX: DesktopMenuState.anchorX + menuWidth + edgeMargin > win.width
            readonly property bool flipY: DesktopMenuState.anchorY + menuCard.height + edgeMargin > win.height

            readonly property real clampedMenuX: {
                const raw = flipX ? DesktopMenuState.anchorX - menuWidth : DesktopMenuState.anchorX;
                return Math.max(edgeMargin, Math.min(raw, win.width - menuWidth - edgeMargin));
            }
            readonly property real clampedMenuY: {
                const raw = flipY ? DesktopMenuState.anchorY - menuCard.height : DesktopMenuState.anchorY;
                return Math.max(edgeMargin, Math.min(raw, win.height - menuCard.height - edgeMargin));
            }

            readonly property bool subFlipX: clampedMenuX + menuWidth + 8 + subMenuWidth + edgeMargin > win.width
            readonly property real clampedSubX: {
                const raw = subFlipX ? clampedMenuX - subMenuWidth - 8 : clampedMenuX + menuWidth + 8;
                return Math.max(edgeMargin, Math.min(raw, win.width - subMenuWidth - edgeMargin));
            }
            readonly property real clampedSubY: {
                const raw = clampedMenuY + submenuTriggerY - 6;
                return Math.max(edgeMargin, Math.min(raw, win.height - submenuCard.height - edgeMargin));
            }

            screen: modelData
            name: "desktop-menu"
            WlrLayershell.exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: isOpen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
            color: "transparent"
            surfaceFormat.opaque: false
            visible: isOpen || keepVisible
            mask: isOpen ? null : emptyRegion

            anchors.top: true
            anchors.bottom: true
            anchors.left: true
            anchors.right: true

            Region {
                id: emptyRegion
            }

            onIsOpenChanged: {
                if (isOpen) {
                    closeHideTimer.stop();
                    subCloseTimer.stop();
                    keepVisible = true;
                    activeIndex = -1;
                    openSubmenuIndex = -1;
                    subActiveIndex = -1;
                    Qt.callLater(() => keyHandler.forceActiveFocus());
                } else {
                    openSubmenuIndex = -1;
                    subActiveIndex = -1;
                    closeHideTimer.restart();
                }
            }

            Connections {
                target: DesktopMenuState

                function onOpenCounterChanged(): void {
                    if (win.isOpen) {
                        win.activeIndex = -1;
                        win.openSubmenuIndex = -1;
                        win.subActiveIndex = -1;
                        reopenPopAnim.restart();
                    }
                }
            }

            Timer {
                id: closeHideTimer
                interval: 170
                onTriggered: {
                    if (!win.isOpen)
                        win.keepVisible = false;
                }
            }

            Timer {
                id: subCloseTimer
                interval: 220
                onTriggered: {
                    if (!submenuHover.containsMouse) {
                        win.openSubmenuIndex = -1;
                        win.subActiveIndex = -1;
                    }
                }
            }

            HyprlandFocusGrab {
                active: win.isOpen
                windows: [win]
                onCleared: DesktopMenuState.close()
            }

            // Fullscreen backdrop catcher: left-click closes, right-click immediately reopens at new cursor pos
            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                onPressed: mouse => {
                    if (mouse.button === Qt.RightButton) {
                        DesktopMenuState.openAt(win.modelData, mouse.x, mouse.y);
                    } else {
                        DesktopMenuState.close();
                    }
                }
            }

            // Keyboard navigation handler
            FocusScope {
                id: keyHandler

                anchors.fill: parent
                focus: win.isOpen

                function nextValidIndex(list: var, current: int, delta: int): int {
                    const n = list.length;
                    if (n === 0)
                        return -1;
                    let idx = current;
                    for (let step = 0; step < n; step++) {
                        idx = (idx + delta + n) % n;
                        if (!list[idx].separator)
                            return idx;
                    }
                    return -1;
                }

                Keys.onEscapePressed: {
                    if (win.openSubmenuIndex >= 0) {
                        win.openSubmenuIndex = -1;
                        win.subActiveIndex = -1;
                    } else {
                        DesktopMenuState.close();
                    }
                }

                Keys.onDownPressed: {
                    if (win.openSubmenuIndex >= 0) {
                        win.subActiveIndex = nextValidIndex(win.activeSubmenuItems, win.subActiveIndex, 1);
                    } else {
                        win.activeIndex = nextValidIndex(win.menuItems, win.activeIndex, 1);
                    }
                }

                Keys.onUpPressed: {
                    if (win.openSubmenuIndex >= 0) {
                        win.subActiveIndex = nextValidIndex(win.activeSubmenuItems, win.subActiveIndex, -1);
                    } else {
                        win.activeIndex = nextValidIndex(win.menuItems, win.activeIndex < 0 ? 0 : win.activeIndex, -1);
                    }
                }

                Keys.onRightPressed: {
                    if (win.openSubmenuIndex < 0 && win.activeIndex >= 0) {
                        const item = win.menuItems[win.activeIndex];
                        if (item && item.children) {
                            const row = mainRepeater.itemAt(win.activeIndex);
                            win.submenuTriggerY = row ? row.y + mainCol.anchors.margins : 0;
                            win.openSubmenuIndex = win.activeIndex;
                            win.subActiveIndex = nextValidIndex(item.children, -1, 1);
                        }
                    }
                }

                Keys.onLeftPressed: {
                    if (win.openSubmenuIndex >= 0) {
                        win.openSubmenuIndex = -1;
                        win.subActiveIndex = -1;
                    }
                }

                Keys.onReturnPressed: activateCurrent()
                Keys.onEnterPressed: activateCurrent()

                function activateCurrent(): void {
                    if (win.openSubmenuIndex >= 0 && win.subActiveIndex >= 0) {
                        const sub = win.activeSubmenuItems[win.subActiveIndex];
                        if (sub && !sub.separator)
                            scopeRoot.runAction(sub.id, win.modelData);
                    } else if (win.activeIndex >= 0) {
                        const item = win.menuItems[win.activeIndex];
                        if (!item || item.separator)
                            return;
                        if (item.children) {
                            const row = mainRepeater.itemAt(win.activeIndex);
                            win.submenuTriggerY = row ? row.y + mainCol.anchors.margins : 0;
                            win.openSubmenuIndex = win.activeIndex;
                            win.subActiveIndex = nextValidIndex(item.children, -1, 1);
                        } else {
                            scopeRoot.runAction(item.id, win.modelData);
                        }
                    }
                }
            }

            // Main Liquid Glass Context Menu Card
            Item {
                id: menuCard

                x: win.clampedMenuX
                y: win.clampedMenuY
                width: win.menuWidth
                height: mainCol.implicitHeight + mainCol.anchors.margins * 2

                opacity: win.isOpen ? 1 : 0
                scale: win.isOpen ? 1 : 0.92
                transformOrigin: {
                    if (win.flipX && win.flipY)
                        return Item.BottomRight;
                    if (win.flipX)
                        return Item.TopRight;
                    if (win.flipY)
                        return Item.BottomLeft;
                    return Item.TopLeft;
                }

                Behavior on opacity {
                    NumberAnimation {
                        duration: 145
                        easing.type: Easing.OutCubic
                    }
                }

                Behavior on scale {
                    NumberAnimation {
                        duration: 185
                        easing.type: Easing.OutBack
                        easing.overshoot: 0.7
                    }
                }

                SequentialAnimation {
                    id: reopenPopAnim
                    PropertyAction {
                        target: menuCard
                        property: "scale"
                        value: 0.93
                    }
                    PropertyAction {
                        target: menuCard
                        property: "opacity"
                        value: 0.65
                    }
                    ParallelAnimation {
                        NumberAnimation {
                            target: menuCard
                            property: "scale"
                            to: 1.0
                            duration: 170
                            easing.type: Easing.OutBack
                            easing.overshoot: 0.65
                        }
                        NumberAnimation {
                            target: menuCard
                            property: "opacity"
                            to: 1.0
                            duration: 130
                            easing.type: Easing.OutCubic
                        }
                    }
                }

                GlassSurface {
                    anchors.fill: parent
                    radius: 18
                }

                // Absorb clicks inside the card so backdrop MouseArea doesn't dismiss
                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.AllButtons
                    hoverEnabled: true
                    onPressed: mouse => mouse.accepted = true
                }

                ColumnLayout {
                    id: mainCol

                    anchors.fill: parent
                    anchors.margins: 7
                    spacing: 2

                    Repeater {
                        id: mainRepeater

                        model: win.menuItems

                        delegate: Item {
                            id: rowItem

                            required property var modelData
                            required property int index

                            readonly property bool isSep: modelData.separator === true
                            readonly property bool hasSub: Boolean(modelData.children && modelData.children.length > 0)
                            readonly property bool isHighlighted: win.activeIndex === index || (hasSub && win.openSubmenuIndex === index)

                            Layout.fillWidth: true
                            implicitHeight: isSep ? 9 : 34

                            // Hairline glass divider
                            Rectangle {
                                visible: rowItem.isSep
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.leftMargin: 10
                                anchors.rightMargin: 10
                                height: 1
                                color: Qt.rgba(1, 1, 1, Colours.light ? 0.28 : 0.12)
                            }

                            // Interactive menu item row
                            Item {
                                visible: !rowItem.isSep
                                anchors.fill: parent

                                // Frosted liquid-glass hover pill
                                Rectangle {
                                    anchors.fill: parent
                                    radius: 11
                                    color: rowItem.isHighlighted
                                        ? Qt.alpha(Colours.palette.m3primary, Colours.light ? 0.22 : 0.26)
                                        : "transparent"
                                    border.width: rowItem.isHighlighted ? 1 : 0
                                    border.color: Qt.alpha(Colours.palette.m3primary, Colours.light ? 0.36 : 0.42)

                                    Behavior on color {
                                        ColorAnimation {
                                            duration: 110
                                        }
                                    }
                                }

                                // Top micro-highlight on hovered pill
                                Rectangle {
                                    visible: rowItem.isHighlighted
                                    anchors.top: parent.top
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.topMargin: 1
                                    anchors.leftMargin: 10
                                    anchors.rightMargin: 10
                                    height: 1
                                    color: Qt.rgba(1, 1, 1, Colours.light ? 0.45 : 0.22)
                                }

                                StateLayer {
                                    radius: 11
                                    showHoverBackground: false
                                    color: Colours.palette.m3primary
                                    onEntered: {
                                        win.activeIndex = rowItem.index;
                                        if (rowItem.hasSub) {
                                            subCloseTimer.stop();
                                            win.submenuTriggerY = rowItem.y + mainCol.anchors.margins;
                                            win.openSubmenuIndex = rowItem.index;
                                            win.subActiveIndex = -1;
                                        } else if (win.openSubmenuIndex >= 0) {
                                            subCloseTimer.restart();
                                        }
                                    }
                                    onExited: {
                                        if (win.activeIndex === rowItem.index && win.openSubmenuIndex !== rowItem.index)
                                            win.activeIndex = -1;
                                    }
                                    onClicked: {
                                        if (rowItem.hasSub) {
                                            subCloseTimer.stop();
                                            win.submenuTriggerY = rowItem.y + mainCol.anchors.margins;
                                            win.openSubmenuIndex = rowItem.index;
                                        } else {
                                            scopeRoot.runAction(rowItem.modelData.id, win.modelData);
                                        }
                                    }
                                }

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 10
                                    anchors.rightMargin: 10
                                    spacing: 10

                                    Item {
                                        Layout.alignment: Qt.AlignVCenter
                                        Layout.preferredWidth: 18
                                        Layout.preferredHeight: 18

                                        Image {
                                            visible: (rowItem.modelData.svgIcon ?? "") !== ""
                                            anchors.centerIn: parent
                                            width: 17
                                            height: 17
                                            source: (rowItem.modelData.svgIcon ?? "") !== "" ? Qt.resolvedUrl(rowItem.modelData.svgIcon) : ""
                                            sourceSize.width: 34
                                            sourceSize.height: 34
                                            smooth: true
                                            mipmap: true
                                        }

                                        MaterialIcon {
                                            visible: (rowItem.modelData.svgIcon ?? "") === ""
                                            anchors.centerIn: parent
                                            text: rowItem.modelData.icon ?? ""
                                            fontStyle: Tokens.font.icon.small
                                            fill: rowItem.isHighlighted ? 1 : 0
                                            color: rowItem.isHighlighted
                                                ? Colours.palette.m3primary
                                                : Colours.palette.m3onSurfaceVariant

                                            Behavior on fill {
                                                NumberAnimation {
                                                    duration: 140
                                                }
                                            }
                                        }
                                    }

                                    StyledText {
                                        Layout.alignment: Qt.AlignVCenter
                                        Layout.fillWidth: true
                                        text: rowItem.modelData.label ?? ""
                                        font: Tokens.font.body.small
                                        elide: Text.ElideRight
                                        color: Colours.palette.m3onSurface
                                    }

                                    StyledText {
                                        visible: !rowItem.hasSub && (rowItem.modelData.shortcut ?? "") !== ""
                                        Layout.alignment: Qt.AlignVCenter
                                        text: rowItem.modelData.shortcut ?? ""
                                        font: Tokens.font.label.small
                                        color: Qt.alpha(Colours.palette.m3onSurface, 0.68)
                                    }

                                    MaterialIcon {
                                        visible: rowItem.hasSub
                                        Layout.alignment: Qt.AlignVCenter
                                        text: "chevron_right"
                                        fontStyle: Tokens.font.icon.small
                                        color: rowItem.isHighlighted
                                            ? Colours.palette.m3primary
                                            : Colours.palette.m3onSurfaceVariant
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // Floating Liquid Glass Submenu Card
            Item {
                id: submenuCard

                readonly property bool subVisible: win.isOpen && win.openSubmenuIndex >= 0 && win.activeSubmenuItems.length > 0

                x: win.clampedSubX
                y: win.clampedSubY
                width: win.subMenuWidth
                height: subCol.implicitHeight + subCol.anchors.margins * 2

                visible: opacity > 0.01
                opacity: subVisible ? 1 : 0
                scale: subVisible ? 1 : 0.94
                transformOrigin: win.subFlipX ? Item.TopRight : Item.TopLeft

                Behavior on opacity {
                    NumberAnimation {
                        duration: 120
                        easing.type: Easing.OutCubic
                    }
                }

                Behavior on scale {
                    NumberAnimation {
                        duration: 150
                        easing.type: Easing.OutCubic
                    }
                }

                GlassSurface {
                    anchors.fill: parent
                    radius: 16
                }

                MouseArea {
                    id: submenuHover

                    anchors.fill: parent
                    acceptedButtons: Qt.AllButtons
                    hoverEnabled: true
                    onEntered: subCloseTimer.stop()
                    onPressed: mouse => mouse.accepted = true
                }

                ColumnLayout {
                    id: subCol

                    anchors.fill: parent
                    anchors.margins: 7
                    spacing: 2

                    Repeater {
                        model: win.activeSubmenuItems

                        delegate: Item {
                            id: subRow

                            required property var modelData
                            required property int index

                            readonly property bool isSep: modelData.separator === true
                            readonly property bool isDanger: modelData.danger === true
                            readonly property bool isHighlighted: win.subActiveIndex === index

                            Layout.fillWidth: true
                            implicitHeight: isSep ? 9 : 33

                            Rectangle {
                                visible: subRow.isSep
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.leftMargin: 10
                                anchors.rightMargin: 10
                                height: 1
                                color: Qt.rgba(1, 1, 1, Colours.light ? 0.28 : 0.12)
                            }

                            Item {
                                visible: !subRow.isSep
                                anchors.fill: parent

                                Rectangle {
                                    anchors.fill: parent
                                    radius: 10
                                    color: subRow.isHighlighted
                                        ? Qt.alpha(subRow.isDanger ? Colours.palette.m3error : Colours.palette.m3primary, Colours.light ? 0.22 : 0.26)
                                        : "transparent"
                                    border.width: subRow.isHighlighted ? 1 : 0
                                    border.color: Qt.alpha(subRow.isDanger ? Colours.palette.m3error : Colours.palette.m3primary, Colours.light ? 0.36 : 0.42)

                                    Behavior on color {
                                        ColorAnimation {
                                            duration: 110
                                        }
                                    }
                                }

                                StateLayer {
                                    radius: 10
                                    showHoverBackground: false
                                    color: subRow.isDanger ? Colours.palette.m3error : Colours.palette.m3primary
                                    onEntered: {
                                        subCloseTimer.stop();
                                        win.subActiveIndex = subRow.index;
                                    }
                                    onExited: {
                                        if (win.subActiveIndex === subRow.index)
                                            win.subActiveIndex = -1;
                                    }
                                    onClicked: scopeRoot.runAction(subRow.modelData.id, win.modelData)
                                }

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 10
                                    anchors.rightMargin: 10
                                    spacing: 10

                                    MaterialIcon {
                                        Layout.alignment: Qt.AlignVCenter
                                        text: subRow.modelData.icon ?? ""
                                        fontStyle: Tokens.font.icon.small
                                        fill: subRow.isHighlighted ? 1 : 0
                                        color: subRow.isDanger
                                            ? Colours.palette.m3error
                                            : subRow.isHighlighted
                                                ? Colours.palette.m3primary
                                                : Colours.palette.m3onSurfaceVariant

                                        Behavior on fill {
                                            NumberAnimation {
                                                duration: 140
                                            }
                                        }
                                    }

                                    StyledText {
                                        Layout.alignment: Qt.AlignVCenter
                                        Layout.fillWidth: true
                                        text: subRow.modelData.label ?? ""
                                        font: Tokens.font.body.small
                                        elide: Text.ElideRight
                                        color: subRow.isDanger ? Colours.palette.m3error : Colours.palette.m3onSurface
                                    }

                                    StyledText {
                                        visible: (subRow.modelData.shortcut ?? "") !== ""
                                        Layout.alignment: Qt.AlignVCenter
                                        text: subRow.modelData.shortcut ?? ""
                                        font: Tokens.font.label.small
                                        color: Qt.alpha(Colours.palette.m3onSurface, 0.68)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
