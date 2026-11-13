pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.I18n
import qs.components
import qs.services
import qs.modules.nexus.common

PageBase {
    id: root

    title: Tr.tr("Plugins")

    readonly property int count: Plugins.plugins.length

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

            ToggleRow {
                required property var modelData
                required property int index

                first: index === 0
                last: index === root.count - 1

                text: modelData.version ? `${modelData.name}  ·  v${modelData.version}` : modelData.name
                subtext: {
                    const schemes = modelData.schemes.length;
                    const caps = schemes > 0 ? Tr.tr("%1 schemes").arg(schemes) : Tr.tr("no features");
                    return modelData.description ? `${modelData.description}  ·  ${caps}` : caps;
                }
                checked: modelData.enabled
                onToggled: Plugins.setEnabled(modelData.id, checked)
            }
        }

        InfoRow {
            visible: root.count === 0
            first: true
            last: true
            icon: "extension_off"
            label: Tr.tr("No plugins installed")
            subtext: Tr.tr("Drop a plugin executable into ~/.config/caelestia/plugins")
        }

        SectionHeader {
            text: Tr.tr("Plugins")
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
}
