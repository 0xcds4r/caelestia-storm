pragma ComponentBehavior: Bound

import "popouts" as BarPopouts
import "components"
import "components/workspaces"
import QtQuick
import QtQuick.Layouts
import Quickshell
import Caelestia.Config
import qs.components
import qs.services

GridLayout {
    id: root

    required property ShellScreen screen
    required property ScreenState screenState
    required property BarPopouts.Wrapper popouts
    required property bool fullscreen
    readonly property int vPadding: Tokens.padding.large
    readonly property bool vertical: BarPos.vertical

    columns: root.vertical ? 1 : -1
    rows: root.vertical ? -1 : 1

    function closeTray(): void {
        if (!Config.bar.tray.compact)
            return;

        for (let i = 0; i < repeater.count; i++) {
            const tray = (repeater.itemAt(i) as EntryWrapper)?.item as Tray;
            if (tray)
                tray.expanded = false;
        }
    }

    function checkPopout(pos: real): void {
        const ch = childAt(root.vertical ? width / 2 : pos, root.vertical ? pos : height / 2) as EntryWrapper;
        if (ch?.entryId !== "tray")
            closeTray();

        if (!ch) {
            popouts.hasCurrent = false;
            return;
        }

        const id = ch.entryId;
        const top = root.vertical ? ch.y : ch.x;

        if (id === "statusIcons" && Config.bar.popouts.statusIcons) {
            const items = (ch.item as StatusIcons).items;
            // The icon row is a GridLayout whose own size can lag behind its children, so hit-test
            // the entry items directly. Horizontal bars are traversed by x, vertical ones by y.
            const local = root.vertical ? mapToItem(items, 0, pos) : mapToItem(items, pos, 0);
            const at = root.vertical ? local.y : local.x;
            let icon = null;
            for (const entry of items.children) {
                if (!entry.name || !entry.visible)
                    continue;
                const start = root.vertical ? entry.y : entry.x;
                const extent = root.vertical ? entry.height : entry.width;
                if (at >= start && at < start + extent) {
                    icon = entry;
                    break;
                }
            }
            if (icon) {
                popouts.currentName = icon.name;
                popouts.currentCenter = Qt.binding(() => root.vertical ? icon.mapToItem(root, 0, icon.implicitHeight / 2).y : icon.mapToItem(root, icon.implicitWidth / 2, 0).x);
                popouts.hasCurrent = true;
            }
        } else if (id === "tray" && Config.bar.popouts.tray) {
            const tray = ch.item as Tray;
            if (!Config.bar.tray.compact || (tray.expanded && !tray.expandIcon.contains(mapToItem(tray.expandIcon, tray.implicitWidth / 2, y)))) {
                const posInTray = (root.vertical ? pos : pos) - top - tray.padding * 2 + tray.spacing;
                const traySize = root.vertical ? tray.layout.implicitHeight : tray.layout.implicitWidth;
                const index = Math.floor((posInTray / traySize) * tray.items.count);
                const trayItem = tray.items.itemAt(index);
                if (trayItem) {
                    popouts.currentName = `traymenu${index}`;
                    popouts.currentCenter = Qt.binding(() => root.vertical ? trayItem.mapToItem(root, 0, trayItem.implicitHeight / 2).y : trayItem.mapToItem(root, trayItem.implicitWidth / 2, 0).x);
                    popouts.hasCurrent = true;
                } else {
                    popouts.hasCurrent = false;
                }
            } else {
                popouts.hasCurrent = false;
                tray.expanded = true;
            }
        } else if (id === "activeWindow" && Hypr.activeToplevel && Config.bar.popouts.activeWindow && Config.bar.activeWindow.showOnHover) {
            popouts.currentName = id.toLowerCase();
            popouts.currentCenter = root.vertical ? ((ch.item as Item).mapToItem(root, 0, (ch.item as Item).implicitHeight / 2).y ?? 0) : ((ch.item as Item).mapToItem(root, (ch.item as Item).implicitWidth / 2, 0).x ?? 0);
            popouts.hasCurrent = true;
        }
    }

    function handleWheel(pos: real, angleDelta: point): void {
        const ch = childAt(root.vertical ? width / 2 : pos, root.vertical ? pos : height / 2) as EntryWrapper;
        if (ch?.entryId === "workspaces" && Config.bar.scrollActions.workspaces) {
            // Workspace scroll
            const mon = Hypr.monitorFor(screen);
            const specialWs = mon?.lastIpcObject.specialWorkspace.name;
            if (specialWs?.length > 0)
                Hypr.dispatch(Hypr.usingLua ? `hl.dsp.workspace.toggle_special("${specialWs.slice(8)}")` : `togglespecialworkspace ${specialWs.slice(8)}`);
            else if (angleDelta.y < 0 || mon.activeWorkspace?.id > 1)
                Hypr.dispatch(Hypr.usingLua ? `hl.dsp.focus({ workspace = "r${angleDelta.y > 0 ? "-" : "+"}1" })` : `workspace r${angleDelta.y > 0 ? "-" : "+"}1`);
        } else if ((root.vertical ? pos < screen.height / 2 : pos < screen.width / 2) && Config.bar.scrollActions.volume) {
            // Volume scroll on top half
            if (angleDelta.y > 0)
                Audio.incrementVolume();
            else if (angleDelta.y < 0)
                Audio.decrementVolume();
        } else if (Config.bar.scrollActions.brightness) {
            // Brightness scroll on bottom half
            const monitor = Brightness.getMonitorForScreen(screen);
            if (angleDelta.y > 0)
                monitor.setBrightness(monitor.brightness + GlobalConfig.services.brightnessIncrement);
            else if (angleDelta.y < 0)
                monitor.setBrightness(monitor.brightness - GlobalConfig.services.brightnessIncrement);
        }
    }

    rowSpacing: Tokens.spacing.medium
    columnSpacing: Tokens.spacing.medium

    // Configured entries plus one slot per widget-capable plugin (before the clock / status icons).
    // Only the *set* of plugin widgets is part of the model, so polling their text does not rebuild
    // the whole repeater.
    readonly property var entries: {
        const configured = root.Config.bar.entries.values.filter(entry => entry.enabled);
        const signature = Plugins.widgetSignature;

        if (!signature)
            return configured;

        const ids = signature.split(",");
        const list = [];
        let inserted = false;

        for (const entry of configured) {
            if (!inserted && (entry.id === "clock" || entry.id === "statusIcons")) {
                for (const id of ids)
                    list.push({
                        id: "pluginWidget",
                        pluginId: id
                    });
                inserted = true;
            }
            list.push(entry);
        }

        if (!inserted)
            for (const id of ids)
                list.push({
                    id: "pluginWidget",
                    pluginId: id
                });

        return list;
    }

    Repeater {
        id: repeater

        model: ScriptModel {
            values: root.entries
        }

        DelegateChooser {
            role: "id"

            DelegateChoice {
                roleValue: "spacer"
                delegate: EntryWrapper {
                    Layout.fillHeight: root.vertical
                    Layout.fillWidth: !root.vertical
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
                    Workspaces {
                        objectName: "taskbarWorkspaces"
                        screen: root.screen
                        fullscreen: root.fullscreen
                    }
                }
            }
            DelegateChoice {
                roleValue: "activeWindow"
                delegate: EntryWrapper {
                    ActiveWindow {
                        objectName: "taskbarActiveWindow"
                        bar: root
                        monitor: Brightness.getMonitorForScreen(root.screen)
                    }
                }
            }
            DelegateChoice {
                roleValue: "tray"
                delegate: EntryWrapper {
                    Tray {
                        objectName: "taskbarTray"
                    }
                }
            }
            DelegateChoice {
                roleValue: "clock"
                delegate: EntryWrapper {
                    Clock {
                        objectName: "taskbarClock"
                    }
                }
            }
            DelegateChoice {
                roleValue: "statusIcons"
                delegate: EntryWrapper {
                    StatusIcons {
                        objectName: "taskbarStatusIcons"
                    }
                }
            }
            DelegateChoice {
                roleValue: "pluginWidget"
                delegate: EntryWrapper {
                    PluginWidget {
                        anchors.fill: parent
                        plugin: Plugins.widgetFor(modelData.pluginId)
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

    component PluginWidget: Item {
        id: widget

        required property var plugin

        readonly property string iconName: widget.plugin?.icon ?? ""
        readonly property string label: widget.plugin?.text ?? ""
        readonly property string pluginId: widget.plugin?.pluginId ?? ""

        implicitWidth: root.vertical ? verticalContent.implicitWidth : horizontalContent.implicitWidth
        implicitHeight: root.vertical ? verticalContent.implicitHeight : horizontalContent.implicitHeight

        Row {
            id: horizontalContent

            visible: !root.vertical
            anchors.centerIn: parent
            spacing: Tokens.spacing.extraSmall

            MaterialIcon {
                text: widget.iconName
                color: Colours.palette.m3onSurfaceVariant
                fontStyle: Tokens.font.icon.small
                animate: true
            }

            StyledText {
                text: widget.label
                color: Colours.palette.m3onSurfaceVariant
                font: Tokens.font.label.small
            }
        }

        Column {
            id: verticalContent

            visible: root.vertical
            anchors.centerIn: parent
            spacing: 0

            MaterialIcon {
                text: widget.iconName
                color: Colours.palette.m3onSurfaceVariant
                fontStyle: Tokens.font.icon.small
                animate: true
            }

            StyledText {
                text: widget.label
                color: Colours.palette.m3onSurfaceVariant
                font: Tokens.font.label.small
            }
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor

            onClicked: Plugins.runWidgetClick(widget.pluginId)
        }
    }

    component EntryWrapper: Item {
        required property var modelData
        required property int index
        default property Item item
        readonly property string entryId: modelData.id

        Layout.topMargin: root.vertical && index === 0 ? root.vPadding : 0
        Layout.bottomMargin: root.vertical && index === repeater.count - 1 ? root.vPadding : 0
        Layout.leftMargin: !root.vertical && index === 0 ? root.vPadding : 0
        Layout.rightMargin: !root.vertical && index === repeater.count - 1 ? root.vPadding : 0
        Layout.alignment: root.vertical ? Qt.AlignHCenter : Qt.AlignVCenter

        implicitWidth: item?.implicitWidth ?? 0
        implicitHeight: item?.implicitHeight ?? 0

        children: item
    }
}
