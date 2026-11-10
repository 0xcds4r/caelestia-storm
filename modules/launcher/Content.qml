pragma ComponentBehavior: Bound

import QtQuick
import Caelestia
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.controls
import qs.services
import qs.modules.launcher.services
import qs.modules.overview
import qs.modules.bar.popouts as BarPopouts

Item {
    id: root

    required property ScreenState screenState
    required property var panels
    required property real maxHeight
    property bool clipboardMode: false

    signal clipboardDismissed()

    readonly property int padding: Tokens.padding.large
    readonly property int rounding: Tokens.rounding.extraLarge

    onClipboardModeChanged: {
        if (clipboardMode)
            Qt.callLater(() => clipboard.forceActiveFocus());
    }

    readonly property bool showOverview: search.text.length === 0 && GlobalConfig.launcher.enabled && !root.clipboardMode

    implicitWidth: listWrapper.width + padding * 2
    implicitHeight: search.height + listWrapper.height + padding + search.anchors.bottomMargin

    Item {
        id: listWrapper

        implicitWidth: root.clipboardMode ? clipboard.implicitWidth : root.showOverview ? overviewRow.implicitWidth : list.width
        implicitHeight: root.clipboardMode ? clipboard.implicitHeight + root.padding : root.showOverview ? overviewRow.implicitHeight + root.padding : list.height + root.padding

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: search.top
        anchors.bottomMargin: root.padding

        ClipboardPanel {
            id: clipboard

            anchors.centerIn: parent
            visible: root.clipboardMode

            onActivated: root.screenState.launcher = false
            onDismissed: root.clipboardDismissed()
        }

        Row {
            id: overviewRow

            anchors.centerIn: parent
            spacing: Tokens.spacing.medium
            visible: root.showOverview

            WorkspaceOverview {
                id: overview

                anchors.top: parent.top
                live: root.screenState.launcher
                widthScale: 0.72
                screen: root.panels.screen

                onWorkspaceChosen: root.screenState.launcher = false
                onWindowChosen: root.screenState.launcher = false
            }

            UtilitiesPanel {
                anchors.top: parent.top
                screenState: root.screenState
                popouts: root.panels.popoutsWrapper
                keepAwakeHeight: Math.round(overview.cellHeight * 0.6)
                contentBottom: overview.cellHeight * 2 + overview.cellSpacing
            }
        }

        ContentList {
            id: list

            visible: !root.showOverview && !root.clipboardMode

            content: root
            screenState: root.screenState
            panels: root.panels
            maxHeight: root.maxHeight - search.implicitHeight - root.padding * 3
            search: search
            padding: root.padding
            rounding: root.rounding
        }
    }

    SearchBar {
        id: search

        visible: !root.clipboardMode
        objectName: "launcherSearch"

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: root.padding
        anchors.bottomMargin: CUtils.clamp(root.padding - Config.border.thickness, 0, root.padding)

        topPadding: Math.round((Tokens.padding.medium + Tokens.padding.large) / 2)
        bottomPadding: Math.round((Tokens.padding.medium + Tokens.padding.large) / 2)

        placeholderText: Tr.tr("Type \"%1\" for commands").arg(GlobalConfig.launcher.actionPrefix)

        onAccepted: {
            if (root.clipboardMode) {
                clipboard.copy(clipboard.currentIndex);
                return;
            }

            if (root.showOverview) {
                overview.activateSelection();
                return;
            }

            const currentItem = list.currentList?.currentItem;
            if (currentItem) {
                if (list.showWallpapers) {
                    if (Colours.scheme === "dynamic" && currentItem.modelData.path !== Wallpapers.actualCurrent)
                        Wallpapers.previewColourLock = true;
                    Wallpapers.setWallpaper(currentItem.modelData.path);
                    root.screenState.launcher = false;
                } else if (text.startsWith(GlobalConfig.launcher.actionPrefix)) {
                    if (text.startsWith(`${GlobalConfig.launcher.actionPrefix}calc `))
                        currentItem.onClicked();
                    else
                        currentItem.modelData.onClicked(list.currentList);
                } else {
                    Apps.launch(currentItem.modelData);
                    root.screenState.launcher = false;
                }
            }
        }

        Keys.onUpPressed: {
            if (root.clipboardMode)
                clipboard.move(-1);
            else if (root.showOverview)
                overview.moveVertical(-1);
            else
                list.currentList?.decrementCurrentIndex();
        }
        Keys.onDownPressed: {
            if (root.clipboardMode)
                clipboard.move(1);
            else if (root.showOverview)
                overview.moveVertical(1);
            else
                list.currentList?.incrementCurrentIndex();
        }
        Keys.onLeftPressed: {
            if (root.showOverview)
                overview.moveHorizontal(-1);
        }
        Keys.onRightPressed: {
            if (root.showOverview)
                overview.moveHorizontal(1);
        }
        Keys.onReturnPressed: {
            if (root.showOverview)
                overview.activateSelection();
        }

        Keys.onEscapePressed: root.screenState.launcher = false

        Keys.onPressed: event => {
            if (!GlobalConfig.launcher.vimKeybinds)
                return;

            if (event.modifiers & Qt.ControlModifier) {
                if (event.key === Qt.Key_J || event.key === Qt.Key_N) {
                    list.currentList?.incrementCurrentIndex();
                    event.accepted = true;
                } else if (event.key === Qt.Key_K || event.key === Qt.Key_P) {
                    list.currentList?.decrementCurrentIndex();
                    event.accepted = true;
                }
            } else if (event.key === Qt.Key_Tab) {
                list.currentList?.incrementCurrentIndex();
                event.accepted = true;
            } else if (event.key === Qt.Key_Backtab || (event.key === Qt.Key_Tab && (event.modifiers & Qt.ShiftModifier))) {
                list.currentList?.decrementCurrentIndex();
                event.accepted = true;
            }
        }

        Component.onCompleted: forceActiveFocus()

        Connections {
            function onLauncherChanged(): void {
                if (!root.screenState.launcher)
                    search.text = "";
            }

            function onSessionChanged(): void {
                if (!root.screenState.session)
                    search.forceActiveFocus();
            }

            target: root.screenState
        }
    }
}
