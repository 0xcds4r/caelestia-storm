pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.controls
import qs.components.filedialog
import qs.services
import qs.modules.nexus.common

PageBase {
    id: root

    title: Tr.tr("Plugins")

    readonly property int count: Plugins.plugins.length

    readonly property FileDialog importDialog: FileDialog {
        title: Tr.tr("Import plugin")
        filterLabel: Tr.tr("Plugin archives")
        filters: ["stormpack"]

        onAccepted: path => Plugins.importArchive(path)
    }

    function importPlugin(): void {
        importDialog.open();
    }

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        SectionHeader {
            first: true
            text: Tr.tr("Installed")
        }

        Repeater {
            model: Plugins.plugins

            PluginRow {
                required property var modelData
                required property int index

                plugin: modelData
                first: index === 0
                last: index === root.count - 1
            }
        }

        InfoRow {
            visible: root.count === 0
            first: true
            last: true
            icon: "extension_off"
            label: Tr.tr("No plugins installed")
            subtext: Tr.tr("Import a .stormpack or drop an executable into ~/.config/caelestia/plugins")
        }

        SectionHeader {
            text: Tr.tr("Manage")
        }

        RowButton {
            first: true
            last: true
            icon: "file_upload"
            text: Tr.tr("Import plugin…")
            subtext: Tr.tr("Install a .stormpack archive")
            onClicked: root.importPlugin()
        }


        SectionHeader {
            text: Tr.tr("Add manually")
        }

        RowButton {
            first: true
            last: true
            icon: "refresh"
            text: Plugins.scanning ? Tr.tr("Scanning…") : Tr.tr("Rescan plugins")
            subtext: Tr.tr("Look for new executables in the plugin directories")
            onClicked: Plugins.refresh()
        }

        StyledText {
            Layout.topMargin: Tokens.spacing.medium
            Layout.fillWidth: true
            text: Tr.tr("A plugin is an executable that answers `info` and `schemes` with JSON. The bundled example lives in examples/rust-plugin of the shell repository.")
            color: Colours.palette.m3onSurfaceVariant
            font: Tokens.font.label.small
            wrapMode: Text.WordWrap
        }
    }

    component PluginRow: ConnectedRect {
        id: row

        required property var plugin

        property bool confirmingDelete: false

        Layout.fillWidth: true
        implicitHeight: rowContent.implicitHeight + Tokens.padding.medium * 2

        Item {
            id: rowContent

            anchors.fill: parent
            anchors.margins: Tokens.padding.medium
            anchors.leftMargin: Tokens.padding.largeIncreased
            anchors.rightMargin: Tokens.padding.largeIncreased

            implicitHeight: texts.implicitHeight

            StyledSwitch {
                id: pluginSwitch

                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter

                checked: row.plugin.enabled
                background: null

                onToggled: Plugins.setEnabled(row.plugin.id, checked)
            }

            IconButton {
                id: removeButton

                anchors.right: pluginSwitch.left
                anchors.rightMargin: Tokens.spacing.small
                anchors.verticalCenter: parent.verticalCenter

                visible: !row.confirmingDelete
                type: IconButton.Text
                icon: "delete"

                onClicked: row.confirmingDelete = true
            }

            Row {
                id: confirmRow

                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: Tokens.spacing.small

                visible: row.confirmingDelete

                TextButton {
                    type: TextButton.Text
                    text: Tr.trCtx("Cancel", "button")

                    onClicked: row.confirmingDelete = false
                }

                TextButton {
                    type: TextButton.Text
                    text: Tr.tr("Delete")

                    inactiveOnColour: Colours.palette.m3error
                    activeOnColour: Colours.palette.m3error

                    onClicked: {
                        row.confirmingDelete = false;
                        Plugins.removePlugin(row.plugin);
                    }
                }
            }

            Column {
                id: texts

                anchors.left: parent.left
                anchors.right: row.confirmingDelete ? confirmRow.left : removeButton.left
                anchors.rightMargin: Tokens.spacing.small
                anchors.verticalCenter: parent.verticalCenter

                spacing: 0

                StyledText {
                    width: parent.width
                    text: row.plugin.version ? `${row.plugin.name}  ·  v${row.plugin.version}` : row.plugin.name
                    font: Tokens.font.body.small
                    elide: Text.ElideRight
                }

                StyledText {
                    width: parent.width
                    visible: row.confirmingDelete
                    text: Tr.tr("Delete %1? The plugin files will be removed.").arg(row.plugin.name)
                    color: Colours.palette.m3error
                    font: Tokens.font.label.small
                    elide: Text.ElideRight
                }

                StyledText {
                    width: parent.width
                    visible: !row.confirmingDelete
                    text: {
                        const schemes = row.plugin.schemes.length;
                        const caps = schemes > 0 ? Tr.tr("%1 schemes").arg(schemes) : Tr.tr("no features");
                        return row.plugin.description ? `${row.plugin.description}  ·  ${caps}` : caps;
                    }
                    color: Colours.palette.m3outline
                    font: Tokens.font.label.small
                    elide: Text.ElideRight
                }
            }
        }
    }
}
