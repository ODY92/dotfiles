pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Caelestia.Config
import qs.components
import qs.services

StyledRect {
    id: root

    required property ShellScreen screen
    required property bool fullscreen

    readonly property int activeWsId: GlobalConfig.bar.workspaces.perMonitorWorkspaces ? (Hypr.monitorFor(screen).activeWorkspace?.id ?? 1) : Hypr.activeWsId

    readonly property var occupied: {
        const occ = {};
        for (const ws of Hypr.workspaces.values)
            occ[ws.id] = ws.lastIpcObject.windows > 0;
        return occ;
    }
    readonly property int groupOffset: Math.floor((activeWsId - 1) / Config.bar.workspaces.shown) * Config.bar.workspaces.shown
    readonly property int cell: Tokens.sizes.bar.innerWidth - Tokens.padding.small

    implicitHeight: Tokens.sizes.bar.innerWidth
    implicitWidth: row.implicitWidth + Tokens.padding.small

    color: Colours.tPalette.m3surfaceContainer
    radius: Tokens.rounding.full
    clip: true

    StyledRect {
        id: indicator

        readonly property int idx: root.activeWsId - root.groupOffset - 1

        visible: Config.bar.workspaces.activeIndicator && idx >= 0 && idx < Config.bar.workspaces.shown
        x: row.x + idx * (root.cell + row.spacing)
        anchors.verticalCenter: parent.verticalCenter
        implicitWidth: root.cell
        implicitHeight: root.cell
        radius: Tokens.rounding.full
        color: Colours.palette.m3primary

        Behavior on x {
            Anim {}
        }
    }

    RowLayout {
        id: row

        anchors.centerIn: parent
        spacing: Math.floor(Tokens.spacing.extraSmall)

        Repeater {
            id: repeater

            model: Config.bar.workspaces.shown

            Item {
                id: cell

                required property int index

                readonly property int wsId: root.groupOffset + index + 1
                readonly property bool isOccupied: root.occupied[wsId] ?? false
                readonly property bool isActive: root.activeWsId === wsId

                Layout.preferredWidth: root.cell
                Layout.preferredHeight: root.cell

                StyledText {
                    anchors.centerIn: parent

                    animate: true
                    text: {
                        const ws = Hypr.workspaces.values.find(w => w.id === cell.wsId);
                        const wsName = !ws || ws.name == cell.wsId ? cell.wsId : ws.name[0];
                        let displayName = wsName.toString();
                        if (Config.bar.workspaces.capitalisation.toLowerCase() === "upper") {
                            displayName = displayName.toUpperCase();
                        } else if (Config.bar.workspaces.capitalisation.toLowerCase() === "lower") {
                            displayName = displayName.toLowerCase();
                        }
                        const label = Config.bar.workspaces.label || displayName;
                        const occupiedLabel = Config.bar.workspaces.occupiedLabel || label;
                        const activeLabel = Config.bar.workspaces.activeLabel || (cell.isOccupied ? occupiedLabel : label);
                        return cell.isActive ? activeLabel : cell.isOccupied ? occupiedLabel : label;
                    }
                    color: cell.isActive && indicator.visible ? Colours.palette.m3onPrimary : (Config.bar.workspaces.occupiedBg || cell.isOccupied || cell.isActive) ? Colours.palette.m3onSurface : Colours.layer(Colours.palette.m3outlineVariant, 2)
                    font.family: Tokens.font.workspaces
                }
            }
        }
    }

    MouseArea {
        anchors.fill: row

        onClicked: event => {
            const ws = (row.childAt(event.x, event.y) as Item)?.wsId;
            if (!ws)
                return;
            if (Hypr.activeWsId !== ws)
                Hypr.dispatch(Hypr.usingLua ? `hl.dsp.focus({ workspace = "${ws}" })` : `workspace ${ws}`);
            else
                Hypr.dispatch(Hypr.usingLua ? 'hl.dsp.workspace.toggle_special("special")' : "togglespecialworkspace special");
        }
    }
}
