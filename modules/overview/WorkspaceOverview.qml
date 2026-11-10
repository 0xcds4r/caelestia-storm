pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import Caelestia
import Caelestia.Config
import qs.components
import qs.components.effects
import qs.services
import qs.utils

Item {
    id: root

    required property ShellScreen screen
    property bool live: true
    property double widthScale: 0.72
    property real cellSpacing: 10

    readonly property int rows: 2
    readonly property int columns: 5
    readonly property int cellCount: rows * columns
    readonly property real pad: 0

    readonly property var monitor: Hypr.monitorFor(screen)
    readonly property int activeWs: monitor?.activeWorkspace?.id ?? 1
    readonly property int liveGroup: Math.floor((activeWs - 1) / cellCount)
    property int pageOffset: 0
    readonly property int group: Math.max(0, liveGroup + pageOffset)
    readonly property int baseWs: group * cellCount + 1

    property int selectedCell: -1
    property int hoveredCell: -1
    property var pendingAction: null

    Process {
        id: readCursor

        command: ["hyprctl", "cursorpos"]

        stdout: StdioCollector {
            onStreamFinished: {
                const match = text.match(/(-?\d+),\s*(-?\d+)/);
                const pos = match ? [parseInt(match[1]), parseInt(match[2])] : null;
                const action = root.pendingAction;
                root.pendingAction = null;
                if (action)
                    action(pos);
            }
        }
    }

    function withCursorPosition(fn): void {
        root.pendingAction = fn;
        readCursor.running = true;
    }

    function focusWindow(addr: string, pos): void {
        const focus = Hypr.usingLua ? `hl.dsp.focus({ window = "address:${addr}" })` : `focuswindow address:${addr}`;

        if (pos)
            Hypr.extras.batchMessage([`dispatch ${focus}`, `dispatch hl.dsp.cursor.move({ x = ${Math.round(pos[0])}, y = ${Math.round(pos[1])} })`]);
        else
            Hypr.dispatch(focus);
    }

    readonly property real availWidth: Math.max(320, screen.width * widthScale)
    readonly property real cellWidth: Math.floor((availWidth - cellSpacing * (columns - 1)) / columns)
    readonly property real cellHeight: Math.round(cellWidth * (screen.height / screen.width))

    readonly property var hyprToplevels: Hypr.toplevels.values
    readonly property var windows: ToplevelManager.toplevels.values.filter(t => {
        const h = hyprFor(t);
        const ws = h?.workspace?.id ?? -1;
        return ws > group * cellCount && ws <= (group + 1) * cellCount;
    })

    readonly property string activeWindowAddress: {
        const candidates = hyprToplevels.filter(t => t.workspace?.id === root.activeWs);
        if (candidates.length === 0)
            return "";
        const sorted = candidates.slice().sort((a, b) => (a.lastIpcObject?.focusHistoryID ?? 999) - (b.lastIpcObject?.focusHistoryID ?? 999));
        return sorted[0]?.address ?? "";
    }

    readonly property int highlightedCell: root.selectedCell >= 0 ? root.selectedCell : Math.max(0, Math.min(root.cellCount - 1, root.activeWs - root.baseWs))

    function topWindowFor(ws: int): var {
        const wsWindows = windows.filter(t => (hyprFor(t)?.workspace?.id ?? -1) === ws);
        if (wsWindows.length === 0)
            return null;
        wsWindows.sort((a, b) => (hyprFor(a)?.lastIpcObject?.focusHistoryID ?? 999) - (hyprFor(b)?.lastIpcObject?.focusHistoryID ?? 999));
        return wsWindows[0];
    }

    function moveVertical(dir: int): void {
        if (selectedCell < 0) {
            selectedCell = Math.max(0, Math.min(cellCount - 1, activeWs - baseWs));
            return;
        }
        const row = Math.floor(selectedCell / columns);
        const col = selectedCell % columns;
        selectedCell = Math.max(0, Math.min(rows - 1, row + dir)) * columns + col;
    }

    function moveHorizontal(dir: int): void {
        if (selectedCell < 0) {
            selectedCell = Math.max(0, Math.min(cellCount - 1, activeWs - baseWs));
            return;
        }
        selectedCell = Math.max(0, Math.min(cellCount - 1, selectedCell + dir));
    }

    function activateSelection(): void {
        const idx = selectedCell < 0 ? Math.max(0, Math.min(cellCount - 1, activeWs - baseWs)) : selectedCell;
        const ws = baseWs + idx;
        const t = topWindowFor(ws);
        const addr = hyprFor(t)?.lastIpcObject?.address;

        windowChosen();

        if (addr)
            withCursorPosition(pos => focusWindow(addr, pos));
        else
            Hypr.focusWorkspace(ws);
    }

    function changePage(dir: int): void {
        pageOffset = Math.max(-liveGroup, pageOffset + dir);
        selectedCell = -1;
    }

    WheelHandler {
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad

        onWheel: event => {
            if (event.angleDelta.y > 0)
                root.changePage(-1);
            else if (event.angleDelta.y < 0)
                root.changePage(1);
            event.accepted = true;
        }
    }

    onVisibleChanged: {
        if (visible) {
            pageOffset = 0;
            selectedCell = -1;
        } else {
            hoveredCell = -1;
        }
    }

    onActiveWsChanged: {
        if (!visible)
            return;
        pageOffset = 0;
        selectedCell = Math.max(0, Math.min(cellCount - 1, activeWs - baseWs));
    }

    function hasWindows(ws: int): bool {
        return windows.some(t => (hyprFor(t)?.workspace?.id ?? -1) === ws);
    }

    function hyprFor(wlToplevel) {
        const addr = wlToplevel?.HyprlandToplevel?.address;
        if (!addr)
            return null;
        return hyprToplevels.find(t => t.address === addr) ?? null;
    }

    clip: true

    signal workspaceChosen()
    signal windowChosen()

    function chooseWorkspace(ws: int): void {
        workspaceChosen();
        Hypr.focusWorkspace(ws);
    }

    implicitWidth: columns * cellWidth + (columns - 1) * cellSpacing + pad * 2
    implicitHeight: rows * cellHeight + (rows - 1) * cellSpacing + pad * 2

    Repeater {
        model: root.cellCount

        Rectangle {
            id: cell

            required property int index

            readonly property int ws: root.baseWs + index

            x: root.pad + (index % root.columns) * (root.cellWidth + root.cellSpacing)
            y: root.pad + Math.floor(index / root.columns) * (root.cellHeight + root.cellSpacing)
            width: root.cellWidth
            height: root.cellHeight
            radius: Tokens.rounding.large
            color: root.hasWindows(ws) ? "#000000" : Qt.rgba(Colours.palette.m3surfaceContainerLow.r, Colours.palette.m3surfaceContainerLow.g, Colours.palette.m3surfaceContainerLow.b, 1)
            border.width: 1
            border.color: Qt.rgba(1, 1, 1, 0.06)

            Text {
                anchors.centerIn: parent
                visible: !root.hasWindows(cell.ws)
                text: cell.ws
                color: Colours.palette.m3onSurface
                opacity: 0.18
                font.pixelSize: Math.round(root.cellHeight * 0.45)
                font.weight: Font.DemiBold
                font.family: Tokens.font.headline.large.family
            }

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true

                onEntered: root.hoveredCell = cell.index
                onExited: {
                    if (root.hoveredCell === cell.index)
                        root.hoveredCell = -1;
                }
                onClicked: root.chooseWorkspace(cell.ws)
            }
        }
    }

    Rectangle {
        id: cellHover

        visible: root.hoveredCell >= 0 && root.hoveredCell !== root.selectedCell
        x: root.pad + (root.hoveredCell % root.columns) * (root.cellWidth + root.cellSpacing)
        y: root.pad + Math.floor(root.hoveredCell / root.columns) * (root.cellHeight + root.cellSpacing)
        width: root.cellWidth
        height: root.cellHeight
        z: 2500
        radius: Tokens.rounding.large
        color: "transparent"
        border.width: 3
        border.color: Qt.rgba(Colours.palette.m3primary.r, Colours.palette.m3primary.g, Colours.palette.m3primary.b, 0.45)
    }

    Rectangle {
        id: cellSelection

        visible: root.highlightedCell >= 0 && root.highlightedCell < root.cellCount
        x: root.pad + (root.highlightedCell % root.columns) * (root.cellWidth + root.cellSpacing)
        y: root.pad + Math.floor(root.highlightedCell / root.columns) * (root.cellHeight + root.cellSpacing)
        width: root.cellWidth
        height: root.cellHeight
        z: 3000
        radius: Tokens.rounding.large
        color: "transparent"
        border.width: 3
        border.color: Colours.palette.m3primary
    }

    Repeater {
        model: ScriptModel {
            values: root.windows
        }

        Item {
            id: preview

            required property var modelData

            readonly property var hypr: root.hyprFor(modelData)
            readonly property var ipc: hypr?.lastIpcObject
            readonly property var mon: Hypr.monitors.values.find(m => (m.lastIpcObject?.id ?? -1) === (ipc?.monitor ?? -1)) ?? null
            readonly property int index: (hypr?.workspace?.id ?? 1) - root.baseWs
            readonly property real cellX: root.pad + (index % root.columns) * (root.cellWidth + root.cellSpacing)
            readonly property real cellY: root.pad + Math.floor(index / root.columns) * (root.cellHeight + root.cellSpacing)
            readonly property var reserved: mon?.lastIpcObject?.reserved ?? [0, 0, 0, 0]
            readonly property real usableX: (mon?.x ?? 0) + (reserved[0] ?? 0)
            readonly property real usableY: (mon?.y ?? 0) + (reserved[1] ?? 0)
            readonly property real usableW: Math.max(1, (mon?.width ?? 1) - (reserved[0] ?? 0) - (reserved[2] ?? 0))
            readonly property real usableH: Math.max(1, (mon?.height ?? 1) - (reserved[1] ?? 0) - (reserved[3] ?? 0))
            readonly property real relX: ipc?.at ? Math.max(0, (ipc.at[0] - usableX) / usableW) : 0
            readonly property real relY: ipc?.at ? Math.max(0, (ipc.at[1] - usableY) / usableH) : 0
            readonly property real innerX: Math.min(relX * root.cellWidth, root.cellWidth - preview.inset)
            readonly property real innerY: Math.min(relY * root.cellHeight, root.cellHeight - preview.inset)
            readonly property real inset: 24
            readonly property real homeX: cellX + innerX
            readonly property real homeY: cellY + innerY
            readonly property real homeWidth: Math.max(preview.inset, Math.min(ipc?.size ? (ipc.size[0] / usableW) * root.cellWidth : root.cellWidth * 0.5, root.cellWidth - innerX))
            readonly property real homeHeight: Math.max(preview.inset, Math.min(ipc?.size ? (ipc.size[1] / usableH) * root.cellHeight : root.cellHeight * 0.5, root.cellHeight - innerY))

            property bool dragging: false


            x: homeX
            y: homeY
            width: homeWidth
            height: homeHeight
            z: dragging ? 1000 : 10

            onHomeXChanged: if (!dragging)
                x = homeX
            onHomeYChanged: if (!dragging)
                y = homeY

            Item {
                id: frame

                anchors.fill: parent
                layer.enabled: true
                layer.effect: Mask {
                    maskSource: maskRect
                }

                Rectangle {
                    id: maskRect

                    anchors.fill: parent
                    radius: Tokens.rounding.large
                    color: "black"
                    visible: false
                    layer.enabled: true
                }

                Rectangle {
                    anchors.fill: parent
                    radius: Tokens.rounding.large
                    color: "#000000"
                }

                ScreencopyView {
                    anchors.fill: parent
                    captureSource: root.live ? preview.modelData : null
                    live: true
                    paintCursor: false
                }

                Image {
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.margins: 6
                    width: Math.max(14, Math.min(parent.width, parent.height) * 0.16)
                    height: width
                    sourceSize.width: width * 2
                    sourceSize.height: height * 2
                    fillMode: Image.PreserveAspectFit
                    visible: status === Image.Ready
                    opacity: 0.9
                    source: Icons.getAppIcon(preview.ipc?.class ?? "", "application-x-executable")
                }
            }

            Rectangle {
                anchors.fill: parent
                radius: Tokens.rounding.large
                color: "transparent"
                border.width: preview.dragging || preview.isActiveWindow ? 3 : 1
                border.color: preview.dragging || preview.isActiveWindow ? Colours.palette.m3primary : Qt.rgba(1, 1, 1, 0.08)
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                drag.target: preview

                drag.threshold: 6

                onPressed: preview.dragging = false
                onPositionChanged: if (drag.active)
                    preview.dragging = true
                onReleased: {
                    if (!preview.dragging) {
                        preview.x = preview.homeX;
                        preview.y = preview.homeY;
                        return;
                    }

                    const col = Math.max(0, Math.min(root.columns - 1, Math.floor((preview.x + preview.width / 2) / (root.cellWidth + root.cellSpacing))));
                    const row = Math.max(0, Math.min(root.rows - 1, Math.floor((preview.y + preview.height / 2) / (root.cellHeight + root.cellSpacing))));
                    const targetWs = root.baseWs + row * root.columns + col;
                    const addr = preview.ipc?.address;

                    preview.dragging = false;

                    if (targetWs !== (preview.hypr?.workspace?.id ?? -1) && addr)
                        Hypr.dispatch(Hypr.usingLua ? `hl.dsp.window.move({ workspace = ${targetWs}, window = "address:${addr}", follow = false })` : `movetoworkspacesilent ${targetWs},address:${addr}`);

                    preview.x = preview.homeX;
                    preview.y = preview.homeY;
                }

                onClicked: mouse => {
                    const addr = preview.ipc?.address;
                    if (!addr)
                        return;
                    const pos = preview.mapToGlobal(mouse.x, mouse.y);
                    root.windowChosen();
                    root.focusWindow(addr, [pos.x, pos.y]);
                }
            }
        }
    }
}
