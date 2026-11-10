pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Caelestia.Config
import qs.components
import qs.modules.launcher.services

Item {
    id: root

    required property ShellScreen screen
    required property ScreenState screenState
    required property var panels

    readonly property bool shouldBeActive: screenState.launcher && Config.launcher.enabled

    readonly property real maxHeight: {
        let max = screen.height - Config.border.thickness * 2 + Tokens.padding.extraLarge;
        if (screenState.dashboard)
            max -= panels.dashboard.nonAnimHeight;
        return max;
    }

    property real offsetScale: shouldBeActive ? 0 : 1

    onShouldBeActiveChanged: {
        if (shouldBeActive) {
            implicitHeight = Qt.binding(() => content.implicitHeight);
        } else {
            root.screenState.clipboardMode = false;
            implicitHeight = implicitHeight; // Break binding during close anim
        }
    }

    visible: offsetScale < 1
    anchors.bottomMargin: (-implicitHeight - 5) * offsetScale
    implicitHeight: content.implicitHeight
    implicitWidth: content.implicitWidth || 630 // Hard coded fallback for first open
    opacity: 1 - offsetScale

    Component.onCompleted: Qt.callLater(() => Apps) // Load apps on init

    // Local patch: dashboard is only expanded while the launcher (Super) is open
    Connections {
        function onLauncherChanged(): void {
            if (Config.dashboard.enabled)
                root.screenState.dashboard = root.screenState.launcher;

            // Local patch: the launcher owns the screen, dismiss any tray popout
            if (root.screenState.launcher) {
                root.panels.popouts.hasCurrent = false;
                root.panels.bar.closeTray();
            }
        }

        target: root.screenState
    }

    Behavior on offsetScale {
        Anim {}
    }

    Loader {
        id: content

        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter

        active: root.shouldBeActive || root.visible

        sourceComponent: Content {
            screenState: root.screenState
            panels: root.panels
            maxHeight: root.maxHeight
            clipboardMode: root.screenState.clipboardMode

            onClipboardDismissed: root.screenState.clipboardMode = false
        }
    }
}
