pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.controls
import qs.services
import qs.modules.nexus.common

// A window declared by a plugin: `plugin window` returns a JSON descriptor, the shell renders it
// with its own components. Control changes are sent back as `plugin event <id> <json>`.
FloatingWindow {
    id: win

    required property var plugin

    property var descriptor: null
    property string currentPage: ""

    readonly property var pages: win.descriptor?.pages ?? []
    readonly property var page: win.pages.find(p => p.id === win.currentPage) ?? win.pages[0] ?? null
    readonly property color surface: Colours.tPalette.m3surface

    function reload(): void {
        loadProc.running = true;
    }

    title: win.descriptor?.title ?? win.plugin.name
    color: win.surface
    surfaceFormat.opaque: false
    implicitWidth: win.descriptor?.width ?? 640
    implicitHeight: win.descriptor?.height ?? 520
    minimumSize.width: 420
    minimumSize.height: 320

    onVisibleChanged: {
        if (!visible)
            destroy();
    }

    onPluginChanged: win.reload()
    Component.onCompleted: win.reload()

    Connections {
        function onEventFinished(pluginId: string): void {
            if (pluginId === win.plugin.id)
                win.reload();
        }

        function onPluginDisabled(pluginId: string): void {
            if (pluginId === win.plugin.id)
                win.destroy();
        }

        target: Plugins
    }

    Process {
        id: loadProc

        command: [win.plugin.path, "window"]

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    win.descriptor = JSON.parse(text);
                    if (!win.pages.some(page => page.id === win.currentPage))
                        win.currentPage = win.pages[0]?.id ?? "";
                } catch (error) {
                    console.warn(`plugin ${win.plugin.id}: invalid window descriptor: ${error}`);
                }
            }
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        RowLayout {
            Layout.fillWidth: true
            Layout.margins: Tokens.padding.largeIncreased
            spacing: Tokens.spacing.medium

            StyledRect {
                Layout.alignment: Qt.AlignVCenter
                implicitWidth: implicitHeight
                implicitHeight: Tokens.padding.extraLarge * 2
                radius: Tokens.rounding.full
                color: Colours.palette.m3secondaryContainer

                MaterialIcon {
                    anchors.centerIn: parent
                    text: win.descriptor?.icon ?? "tune"
                    color: Colours.palette.m3onSecondaryContainer
                    fontStyle: Tokens.font.icon.medium
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0

                StyledText {
                    Layout.fillWidth: true
                    text: win.title
                    font: Tokens.font.title.medium
                    elide: Text.ElideRight
                }

                StyledText {
                    Layout.fillWidth: true
                    text: win.plugin.name
                    color: Colours.palette.m3onSurfaceVariant
                    font: Tokens.font.label.small
                    elide: Text.ElideRight
                }
            }

            IconButton {
                Layout.alignment: Qt.AlignVCenter
                type: IconButton.Text
                icon: "close"

                onClicked: win.destroy()
            }
        }

        Row {
            Layout.fillWidth: true
            Layout.leftMargin: Tokens.padding.largeIncreased
            Layout.rightMargin: Tokens.padding.largeIncreased
            Layout.bottomMargin: Tokens.padding.medium
            spacing: Tokens.spacing.small
            visible: win.pages.length > 1

            Repeater {
                model: win.pages

                TextButton {
                    required property var modelData

                    type: win.currentPage === modelData.id ? TextButton.Filled : TextButton.Text
                    text: modelData.label ?? modelData.id

                    onClicked: win.currentPage = modelData.id
                }
            }
        }

        Flickable {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.leftMargin: Tokens.padding.largeIncreased
            Layout.rightMargin: Tokens.padding.largeIncreased
            Layout.bottomMargin: Tokens.padding.largeIncreased

            contentHeight: contentColumn.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            ColumnLayout {
                id: contentColumn

                width: parent.width
                spacing: Tokens.spacing.extraSmall / 2

                Repeater {
                    model: win.page?.sections ?? []

                    DelegateChooser {
                        role: "type"

                        DelegateChoice {
                            roleValue: "section"
                            delegate: SectionHeader {
                                required property var modelData

                                first: true
                                text: modelData.text ?? ""
                            }
                        }

                        DelegateChoice {
                            roleValue: "text"
                            delegate: StyledText {
                                required property var modelData

                                Layout.fillWidth: true
                                Layout.margins: Tokens.padding.medium
                                text: modelData.text ?? ""
                                color: Colours.palette.m3onSurfaceVariant
                                font: Tokens.font.body.small
                                wrapMode: Text.Wrap
                            }
                        }

                        DelegateChoice {
                            roleValue: "info"
                            delegate: InfoRow {
                                required property var modelData

                                first: true
                                last: true
                                label: modelData.label ?? ""
                                subtext: modelData.subtext ?? ""
                                value: modelData.value ?? ""
                            }
                        }

                        DelegateChoice {
                            roleValue: "toggle"
                            delegate: ToggleRow {
                                required property var modelData

                                first: true
                                last: true
                                text: modelData.label ?? modelData.id
                                subtext: modelData.subtext ?? ""
                                checked: modelData.value === true

                                onToggled: Plugins.sendEvent(win.plugin, modelData.id, checked)
                            }
                        }

                        DelegateChoice {
                            roleValue: "button"
                            delegate: RowButton {
                                required property var modelData

                                first: true
                                last: true
                                icon: modelData.icon ?? "chevron_right"
                                text: modelData.label ?? modelData.id
                                subtext: modelData.subtext ?? ""

                                onClicked: Plugins.sendEvent(win.plugin, modelData.id, true)
                            }
                        }

                        DelegateChoice {
                            roleValue: "textfield"
                            delegate: TextFieldRow {
                                required property var modelData

                                first: true
                                last: true
                                label: modelData.label ?? modelData.id
                                subtext: modelData.subtext ?? ""
                                placeholderText: modelData.placeholder ?? ""
                                value: modelData.value ?? ""

                                onEditingFinished: value => Plugins.sendEvent(win.plugin, modelData.id, value)
                            }
                        }

                        DelegateChoice {
                            roleValue: "slider"
                            delegate: SliderRow {
                                required property var modelData

                                readonly property real low: modelData.min ?? 0
                                readonly property real high: modelData.max ?? 100

                                first: true
                                last: true
                                icon: modelData.icon ?? ""
                                label: modelData.label ?? modelData.id
                                valueLabel: Math.round(low + value * (high - low)).toString()
                                value: ((modelData.value ?? 0) - low) / Math.max(1, high - low)

                                onMoved: value => Plugins.sendEvent(win.plugin, modelData.id, low + value * (high - low))
                            }
                        }

                        DelegateChoice {
                            roleValue: "webview"
                            delegate: Item {
                                required property var modelData

                                Layout.fillWidth: true
                                implicitHeight: modelData.height ?? 280

                                StyledClippingRect {
                                    anchors.fill: parent
                                    radius: Tokens.rounding.medium

                                    WebSnapshot {
                                        anchors.fill: parent
                                        url: modelData.url ?? ""
                                        captureWidth: 900
                                        captureHeight: Math.round(parent.height) || 280
                                        refreshInterval: modelData.refresh ?? 60000
                                    }
                                }
                            }
                        }

                        DelegateChoice {
                            roleValue: "choice"
                            delegate: ConnectedRect {
                                id: choiceRoot

                                required property var modelData

                                first: true
                                last: true
                                Layout.fillWidth: true
                                implicitHeight: choiceColumn.implicitHeight + Tokens.padding.medium * 2

                                ColumnLayout {
                                    id: choiceColumn

                                    anchors.fill: parent
                                    anchors.margins: Tokens.padding.medium
                                    anchors.leftMargin: Tokens.padding.largeIncreased
                                    anchors.rightMargin: Tokens.padding.largeIncreased
                                    spacing: Tokens.spacing.small

                                    StyledText {
                                        Layout.fillWidth: true
                                        text: choiceRoot.modelData.label ?? choiceRoot.modelData.id
                                        font: Tokens.font.body.small
                                    }

                                    Flow {
                                        Layout.fillWidth: true
                                        spacing: Tokens.spacing.small

                                        Repeater {
                                            model: choiceRoot.modelData.options ?? []

                                            TextButton {
                                                required property var modelData

                                                readonly property bool active: (choiceRoot.modelData.value ?? "") === (modelData.value ?? "")

                                                type: active ? TextButton.Filled : TextButton.Text
                                                text: modelData.text ?? modelData.value ?? ""

                                                onClicked: Plugins.sendEvent(win.plugin, choiceRoot.modelData.id, modelData.value)
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
    }
}
