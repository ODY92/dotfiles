pragma ComponentBehavior: Bound

import "popouts" as BarPopouts
import "components"
import QtQuick
import QtQuick.Layouts
import Quickshell
import Caelestia.Config
import qs.components
import qs.services

RowLayout {
    id: root

    required property ShellScreen screen
    required property ScreenState screenState
    required property BarPopouts.Wrapper popouts
    required property bool fullscreen
    readonly property int hPadding: Tokens.padding.large

    function closeTray(): void {
    }

    function checkPopout(px: real): void {
        if (popouts.clickOpened)
            return;

        const ch = childAt(px, height / 2) as EntryWrapper;

        if (!ch) {
            popouts.hasCurrent = false;
            return;
        }

        const id = ch.entryId;

        if (id === "statusIcons" && Config.bar.popouts.statusIcons) {
            const items = (ch.item as HStatus).items;
            const icon = items.childAt(mapToItem(items, px, 0).x, items.height / 2);
            if (icon) {
                popouts.currentName = icon.name;
                popouts.currentCenter = Qt.binding(() => icon.mapToItem(root, icon.implicitWidth / 2, 0).x);
                popouts.hasCurrent = true;
            }
        } else if (id === "tray" && Config.bar.popouts.tray) {
            const tray = ch.item as HTray;
            let found = false;
            for (let i = 0; i < tray.items.count; i++) {
                const it = tray.items.itemAt(i);
                if (!it)
                    continue;
                const left = it.mapToItem(root, 0, 0).x;
                if (px >= left && px <= left + it.width) {
                    popouts.currentName = `traymenu${i}`;
                    popouts.currentCenter = Qt.binding(() => it.mapToItem(root, it.implicitWidth / 2, 0).x);
                    popouts.hasCurrent = true;
                    found = true;
                    break;
                }
            }
            if (!found)
                popouts.hasCurrent = false;
        } else if (id === "activeWindow" && Config.bar.popouts.activeWindow && Config.bar.activeWindow.showOnHover) {
            popouts.currentName = id.toLowerCase();
            popouts.currentCenter = (ch.item as Item).mapToItem(root, (ch.item as Item).implicitWidth / 2, 0).x;
            popouts.hasCurrent = true;
        } else {
            popouts.hasCurrent = false;
        }
    }

    function handleWheel(px: real, angleDelta: point): void {
        const ch = childAt(px, height / 2) as EntryWrapper;
        if (ch?.entryId === "workspaces" && Config.bar.scrollActions.workspaces) {
            const mon = (GlobalConfig.bar.workspaces.perMonitorWorkspaces ? Hypr.monitorFor(screen) : Hypr.focusedMonitor);
            const specialWs = mon?.lastIpcObject.specialWorkspace.name;
            if (specialWs?.length > 0)
                Hypr.dispatch(Hypr.usingLua ? `hl.dsp.workspace.toggle_special("${specialWs.slice(8)}")` : `togglespecialworkspace ${specialWs.slice(8)}`);
            else if (angleDelta.y < 0 || (GlobalConfig.bar.workspaces.perMonitorWorkspaces ? mon.activeWorkspace?.id : Hypr.activeWsId) > 1)
                Hypr.dispatch(Hypr.usingLua ? `hl.dsp.focus({ workspace = "r${angleDelta.y > 0 ? "-" : "+"}1" })` : `workspace r${angleDelta.y > 0 ? "-" : "+"}1`);
        }
    }

    spacing: Tokens.spacing.medium

    Repeater {
        id: repeater

        model: ScriptModel {
            values: {
                const list = [];
                for (const e of root.Config.bar.entries.elements) {
                    if (!e.enabled)
                        continue;
                    if (e.id === "statusIcons" && Peripherals.hasAny)
                        list.push({ id: "peripherals", enabled: true });
                    list.push(e);
                }
                return list;
            }
        }

        DelegateChooser {
            role: "id"

            DelegateChoice {
                roleValue: "spacer"
                delegate: EntryWrapper {
                    Layout.fillWidth: true
                }
            }
            DelegateChoice {
                roleValue: "logo"
                delegate: EntryWrapper {
                    OsIcon {
                        objectName: "taskbarLogo"
                    }
                }
            }
            DelegateChoice {
                roleValue: "workspaces"
                delegate: EntryWrapper {
                    HWorkspaces {
                        objectName: "taskbarWorkspaces"
                        screen: root.screen
                        fullscreen: root.fullscreen
                    }
                }
            }
            DelegateChoice {
                roleValue: "activeWindow"
                delegate: EntryWrapper {
                    HActiveWindow {
                        objectName: "taskbarActiveWindow"
                        bar: root
                    }
                }
            }
            DelegateChoice {
                roleValue: "tray"
                delegate: EntryWrapper {
                    HTray {
                        objectName: "taskbarTray"
                        bar: root
                    }
                }
            }
            DelegateChoice {
                roleValue: "clock"
                delegate: EntryWrapper {
                    HClock {
                        objectName: "taskbarClock"
                        bar: root
                    }
                }
            }
            DelegateChoice {
                roleValue: "peripherals"
                delegate: EntryWrapper {
                    HPeripherals {
                        objectName: "taskbarPeripherals"
                        bar: root
                    }
                }
            }
            DelegateChoice {
                roleValue: "statusIcons"
                delegate: EntryWrapper {
                    HStatus {
                        objectName: "taskbarStatusIcons"
                        bar: root
                    }
                }
            }
            DelegateChoice {
                roleValue: "power"
                delegate: EntryWrapper {
                    Power {
                        objectName: "taskbarPowerButton"
                        screenState: root.screenState
                    }
                }
            }
        }
    }

    component EntryWrapper: Item {
        required property var modelData
        required property int index
        default property Item item
        readonly property string entryId: modelData.id

        Layout.leftMargin: index === 0 ? root.hPadding : 0
        Layout.rightMargin: index === repeater.count - 1 ? root.hPadding : 0
        Layout.alignment: Qt.AlignVCenter

        implicitWidth: item?.implicitWidth ?? 0
        implicitHeight: item?.implicitHeight ?? 0

        children: item
    }
}
