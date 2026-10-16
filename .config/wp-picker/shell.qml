import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets
import QtQuick
import QtQuick.Effects

ShellRoot {
    id: root

    // ---------- couleurs du thème Caelestia ----------
    function sc(key, fallback) {
        try {
            const c = JSON.parse(schemeFile.text()).colours
            return c && c[key] ? "#" + c[key] : fallback
        } catch (e) { return fallback }
    }

    property var items: {
        try { return JSON.parse(listFile.text()) } catch (e) { return [] }
    }
    property color accent: sc("primary", "#a483da")
    property color bg: sc("surface", "#14121c")
    property color fg: sc("onSurface", "#e6e0f0")
    property string currentId: {
        try { return lastFile.text().trim() } catch (e) { return "" }
    }

    // ---------- état ----------
    property string query: ""
    property var filtered: items.filter(i => i.title.toLowerCase().includes(query.toLowerCase()))
    property bool open: false

    property string shownTitle: ""
    property string shownType: ""
    property string shownId: ""

    // fond flouté avec fondu enchaîné (deux calques A / B)
    property string bgA: ""
    property string bgB: ""
    property bool bgFlip: false
    function setBg(path) {
        if (!path || path === (bgFlip ? bgB : bgA)) return
        if (!bgFlip) bgB = path
        else bgA = path
        bgFlip = !bgFlip
    }

    function pick(id) {
        Quickshell.execDetached([Quickshell.env("HOME") + "/.local/bin/wp-apply", id])
        close()
    }
    function close() {
        open = false
        closeTimer.start()
    }

    Component.onCompleted: open = true
    Timer { id: closeTimer; interval: 300; onTriggered: Qt.quit() }

    FileView {
        id: listFile
        path: Quickshell.env("HOME") + "/.cache/wp-list.json"
        blockLoading: true
    }
    FileView {
        id: schemeFile
        path: Quickshell.env("HOME") + "/.local/state/caelestia/scheme.json"
        blockLoading: true
    }
    FileView {
        id: lastFile
        path: Quickshell.env("HOME") + "/.cache/wp-last"
        blockLoading: true
    }

    // calque de fond flouté réutilisable
    component BlurBg: Item {
        id: bgc
        property string path: ""
        property bool shown: false
        opacity: shown ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 600; easing.type: Easing.InOutQuad } }

        Image {
            id: img
            anchors.fill: parent
            source: bgc.path !== "" ? "file://" + bgc.path : ""
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            visible: false
        }
        MultiEffect {
            anchors.fill: parent
            source: img
            blurEnabled: true
            blur: 1.0
            blurMax: 64
            brightness: -0.10
            saturation: 0.45
        }
    }

    PanelWindow {
        anchors { top: true; bottom: true; left: true; right: true }
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

        // ================= décor plein écran =================
        Item {
            anchors.fill: parent
            opacity: root.open ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }

            BlurBg { anchors.fill: parent; path: root.bgA; shown: !root.bgFlip }
            BlurBg { anchors.fill: parent; path: root.bgB; shown: root.bgFlip }

            Rectangle { anchors.fill: parent; color: "black"; opacity: 0.48 }
            Rectangle {
                anchors.fill: parent
                gradient: Gradient {
                    GradientStop { position: 0.0; color: Qt.rgba(0, 0, 0, 0.45) }
                    GradientStop { position: 0.45; color: Qt.rgba(0, 0, 0, 0) }
                    GradientStop { position: 1.0; color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.30) }
                }
            }
            MouseArea { anchors.fill: parent; onClicked: root.close() }
        }

        // ================= contenu =================
        Item {
            id: content
            width: parent.width
            height: parent.height
            y: root.open ? 0 : 26
            opacity: root.open ? 1 : 0
            Behavior on y { NumberAnimation { duration: 480; easing.type: Easing.OutCubic } }
            Behavior on opacity { NumberAnimation { duration: 320; easing.type: Easing.OutCubic } }

            property real cardW: Math.min(width * 0.36, height * 0.92)
            property real cardH: cardW / 2

            function syncUi() {
                const c = carousel.count > 0 ? root.filtered[carousel.currentIndex] : null
                if (c) root.setBg(c.thumb)
                titleAnim.restart()
            }

            // molette (sans bloquer les clics)
            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.NoButton
                onWheel: wheel => {
                    if (wheelLock.running) return
                    const d = wheel.angleDelta.y !== 0 ? wheel.angleDelta.y : wheel.angleDelta.x
                    if (d > 0) carousel.decrementCurrentIndex()
                    else carousel.incrementCurrentIndex()
                    wheelLock.start()
                }
            }
            Timer { id: wheelLock; interval: 110 }

            // ---------- en-tête ----------
            Item {
                id: header
                anchors {
                    top: parent.top; left: parent.left; right: parent.right
                    topMargin: 40; leftMargin: 56; rightMargin: 56
                }
                height: 44

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "WALLPAPERS - ODY92"
                    color: root.accent
                    font.pixelSize: 16
                    font.bold: true
                    font.letterSpacing: 6
                }

                Rectangle {
                    anchors.centerIn: parent
                    height: 40
                    width: pillText.implicitWidth + 48
                    radius: 20
                    color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.20)
                    border.width: 1
                    border.color: root.accent
                    opacity: root.query !== "" ? 1 : 0
                    scale: root.query !== "" ? 1 : 0.85
                    Behavior on opacity { NumberAnimation { duration: 160 } }
                    Behavior on scale { NumberAnimation { duration: 220; easing.type: Easing.OutBack } }
                    Text {
                        id: pillText
                        anchors.centerIn: parent
                        text: root.query
                        color: "white"
                        font.pixelSize: 19
                    }
                }

                Text {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: (carousel.count > 0 ? carousel.currentIndex + 1 : 0) + "  /  " + carousel.count
                    color: Qt.rgba(1, 1, 1, 0.65)
                    font.pixelSize: 16
                    font.letterSpacing: 2
                }
            }

            // ---------- carrousel ----------
            PathView {
                id: carousel
                anchors {
                    left: parent.left; right: parent.right
                    verticalCenter: parent.verticalCenter
                    verticalCenterOffset: -30
                }
                height: content.cardH * 1.25
                focus: true
                interactive: false
                model: root.filtered
                pathItemCount: 7
                preferredHighlightBegin: 0.5
                preferredHighlightEnd: 0.5
                highlightRangeMode: PathView.StrictlyEnforceRange
                highlightMoveDuration: 460

                path: Path {
                    startX: 0
                    startY: carousel.height / 2
                    PathAttribute { name: "iScale"; value: 0.45 }
                    PathAttribute { name: "iAngle"; value: 52 }
                    PathAttribute { name: "iOp"; value: 0.0 }
                    PathAttribute { name: "iZ"; value: 0 }
                    PathLine { x: carousel.width / 2; y: carousel.height / 2 }
                    PathAttribute { name: "iScale"; value: 1.0 }
                    PathAttribute { name: "iAngle"; value: 0 }
                    PathAttribute { name: "iOp"; value: 1.0 }
                    PathAttribute { name: "iZ"; value: 10 }
                    PathLine { x: carousel.width; y: carousel.height / 2 }
                    PathAttribute { name: "iScale"; value: 0.45 }
                    PathAttribute { name: "iAngle"; value: -52 }
                    PathAttribute { name: "iOp"; value: 0.0 }
                    PathAttribute { name: "iZ"; value: 0 }
                }

                onCurrentIndexChanged: content.syncUi()
                onCountChanged: content.syncUi()

                Component.onCompleted: {
                    const i = root.filtered.findIndex(x => x.id === root.currentId)
                    if (i >= 0) {
                        currentIndex = i
                        positionViewAtIndex(i, PathView.Center)
                    }
                    content.syncUi()
                }

                Keys.onPressed: event => {
                    if (event.key === Qt.Key_Left || event.key === Qt.Key_Up) {
                        carousel.decrementCurrentIndex()
                        event.accepted = true
                    } else if (event.key === Qt.Key_Right || event.key === Qt.Key_Down) {
                        carousel.incrementCurrentIndex()
                        event.accepted = true
                    } else if (event.key === Qt.Key_Escape) {
                        if (root.query !== "") {
                            root.query = ""
                            carousel.currentIndex = 0
                        } else root.close()
                        event.accepted = true
                    } else if (event.key === Qt.Key_Backspace) {
                        root.query = root.query.slice(0, -1)
                        carousel.currentIndex = 0
                        event.accepted = true
                    } else if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter)
                               && root.filtered.length > 0) {
                        root.pick(root.filtered[carousel.currentIndex].id)
                        event.accepted = true
                    } else if (event.text.length > 0 && event.text.charCodeAt(0) >= 32
                               && !(event.modifiers & Qt.ControlModifier)) {
                        root.query += event.text
                        carousel.currentIndex = 0
                        event.accepted = true
                    }
                }

                delegate: Item {
                    id: cell
                    required property var modelData
                    required property int index
                    property bool current: PathView.isCurrentItem
                    property bool isActive: modelData.id === root.currentId

                    width: content.cardW
                    height: content.cardH
                    z: PathView.iZ
                    scale: PathView.iScale
                    opacity: PathView.iOp

                    transform: Rotation {
                        origin.x: cell.width / 2
                        origin.y: cell.height / 2
                        axis { x: 0; y: 1; z: 0 }
                        angle: cell.PathView.iAngle
                    }

                    // halo lumineux (carte sélectionnée)
                    Item {
                        anchors.fill: parent
                        opacity: cell.current ? 1 : 0
                        Behavior on opacity { NumberAnimation { duration: 320 } }
                        Repeater {
                            model: 8
                            Rectangle {
                                required property int index
                                anchors.fill: parent
                                anchors.margins: -(index + 1) * 7
                                radius: 24 + (index + 1) * 7
                                color: root.accent
                                opacity: 0.09 * (1 - index / 9)
                            }
                        }
                    }

                    ClippingRectangle {
                        id: card
                        anchors.fill: parent
                        radius: 24
                        color: "#101010"
                        border.width: cell.current ? 3 : 1
                        border.color: cell.current ? root.accent : Qt.rgba(1, 1, 1, 0.14)

                        Image {
                            anchors.fill: parent
                            source: "file://" + cell.modelData.thumb
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            scale: cell.current ? 1.08 : 1.0
                            opacity: status === Image.Ready ? 1 : 0
                            Behavior on scale { NumberAnimation { duration: 1400; easing.type: Easing.OutCubic } }
                            Behavior on opacity { NumberAnimation { duration: 300 } }
                        }

                        // assombrit les cartes éloignées
                        Rectangle {
                            anchors.fill: parent
                            color: "black"
                            opacity: (1 - cell.PathView.iZ / 10) * 0.6
                        }

                        // reflet qui traverse la carte choisie
                        Rectangle {
                            id: shine
                            width: 150
                            height: card.height * 1.8
                            y: -card.height * 0.4
                            x: -300
                            rotation: 20
                            visible: cell.current
                            gradient: Gradient {
                                orientation: Gradient.Horizontal
                                GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, 0) }
                                GradientStop { position: 0.5; color: Qt.rgba(1, 1, 1, 0.20) }
                                GradientStop { position: 1.0; color: Qt.rgba(1, 1, 1, 0) }
                            }
                        }
                        SequentialAnimation {
                            running: cell.current
                            loops: Animation.Infinite
                            PropertyAction { target: shine; property: "x"; value: -300 }
                            PauseAnimation { duration: 1000 }
                            NumberAnimation {
                                target: shine; property: "x"; to: card.width + 200
                                duration: 1400; easing.type: Easing.InOutQuad
                            }
                            PauseAnimation { duration: 3600 }
                        }

                        // badge "ACTUEL"
                        Rectangle {
                            visible: cell.isActive
                            anchors { top: parent.top; left: parent.left; topMargin: 16; leftMargin: 16 }
                            height: 28
                            width: badgeText.implicitWidth + 26
                            radius: 14
                            color: root.accent
                            Text {
                                id: badgeText
                                anchors.centerIn: parent
                                text: "ACTUEL"
                                color: root.bg
                                font.pixelSize: 12
                                font.bold: true
                                font.letterSpacing: 2
                            }
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            if (cell.current) root.pick(cell.modelData.id)
                            else carousel.currentIndex = cell.index
                        }
                    }
                }
            }

            // ---------- titre ----------
            Text {
                id: titleText
                anchors {
                    top: carousel.bottom
                    topMargin: 6
                    horizontalCenter: parent.horizontalCenter
                }
                width: Math.min(content.width * 0.72, 1500)
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
                text: root.shownTitle
                color: "white"
                font.pixelSize: 48
                font.weight: Font.Black
                font.letterSpacing: 1
            }

            Row {
                id: chips
                anchors {
                    top: titleText.bottom
                    topMargin: 14
                    horizontalCenter: parent.horizontalCenter
                }
                spacing: 12
                visible: root.shownTitle !== ""

                Rectangle {
                    visible: root.shownType !== ""
                    anchors.verticalCenter: parent.verticalCenter
                    height: 30
                    width: typeLabel.implicitWidth + 30
                    radius: 15
                    color: Qt.rgba(1, 1, 1, 0.08)
                    border.width: 1
                    border.color: root.shownType === "VIDEO" ? root.accent : "#f0b24a"
                    Text {
                        id: typeLabel
                        anchors.centerIn: parent
                        text: root.shownType
                        color: root.shownType === "VIDEO" ? root.accent : "#f0b24a"
                        font.pixelSize: 13
                        font.bold: true
                        font.letterSpacing: 2
                    }
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "#" + root.shownId
                    color: Qt.rgba(1, 1, 1, 0.45)
                    font.pixelSize: 14
                    font.letterSpacing: 1
                }
            }

            SequentialAnimation {
                id: titleAnim
                NumberAnimation { target: titleText; property: "opacity"; to: 0; duration: 110 }
                ScriptAction {
                    script: {
                        const c = carousel.count > 0 ? root.filtered[carousel.currentIndex] : null
                        root.shownTitle = c ? c.title : ""
                        root.shownType = c && c.type ? c.type.toUpperCase() : ""
                        root.shownId = c ? c.id : ""
                    }
                }
                NumberAnimation { target: titleText; property: "opacity"; to: 1; duration: 280 }
            }

            // ---------- message liste vide ----------
            Text {
                anchors.centerIn: parent
                visible: root.filtered.length === 0
                text: root.items.length === 0
                      ? "Liste vide : lance wp-list dans un terminal"
                      : "Aucun résultat"
                color: "white"
                font.pixelSize: 26
            }

            // ---------- progression + aide ----------
            Rectangle {
                id: track
                anchors {
                    bottom: hints.top
                    bottomMargin: 20
                    horizontalCenter: parent.horizontalCenter
                }
                width: 480
                height: 4
                radius: 2
                color: Qt.rgba(1, 1, 1, 0.16)
                Rectangle {
                    height: parent.height
                    radius: 2
                    color: root.accent
                    width: carousel.count > 1 ? Math.max(28, parent.width / carousel.count) : parent.width
                    x: carousel.count > 1
                       ? (parent.width - width) * carousel.currentIndex / (carousel.count - 1)
                       : 0
                    Behavior on x { NumberAnimation { duration: 380; easing.type: Easing.OutCubic } }
                    Behavior on width { NumberAnimation { duration: 300 } }
                }
            }

            Text {
                id: hints
                anchors {
                    bottom: parent.bottom
                    bottomMargin: 30
                    horizontalCenter: parent.horizontalCenter
                }
                text: "←  →  défiler     ·     Entrée  appliquer     ·     taper  filtrer     ·     Échap  fermer"
                color: Qt.rgba(1, 1, 1, 0.42)
                font.pixelSize: 14
                font.letterSpacing: 1
            }
        }
    }
}
