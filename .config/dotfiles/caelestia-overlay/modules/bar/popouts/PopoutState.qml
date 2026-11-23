import QtQuick

QtObject {
    property string currentName
    property bool hasCurrent
    property bool clickOpened

    signal detachRequested(mode: string)
}
