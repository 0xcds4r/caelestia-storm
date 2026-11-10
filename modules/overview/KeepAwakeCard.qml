pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.controls
import qs.services

StyledRect {
    id: root

    property real cardHeight: 0

    implicitHeight: root.cardHeight

    radius: Tokens.rounding.large
    color: Colours.tPalette.m3surfaceContainer
    clip: true

    RowLayout {
        anchors.fill: parent
        anchors.margins: Tokens.padding.large
        spacing: Tokens.spacing.medium

        StyledRect {
            Layout.alignment: Qt.AlignVCenter
            implicitWidth: implicitHeight
            implicitHeight: icon.implicitHeight + Tokens.padding.large

            radius: Tokens.rounding.full
            color: IdleInhibitor.enabled ? Colours.palette.m3secondary : Colours.palette.m3secondaryContainer

            MaterialIcon {
                id: icon

                anchors.centerIn: parent
                text: "coffee"
                color: IdleInhibitor.enabled ? Colours.palette.m3onSecondary : Colours.palette.m3onSecondaryContainer
                fontStyle: Tokens.font.icon.large
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            spacing: 0

            StyledText {
                Layout.fillWidth: true
                text: Tr.trCtx("Keep awake", "idle inhibitor")
                font: Tokens.font.body.medium
                elide: Text.ElideRight
            }

            StyledText {
                Layout.fillWidth: true
                text: IdleInhibitor.enabled ? Tr.trCtx("Preventing sleep mode", "idle inhibitor") : Tr.trCtx("Normal power management", "idle inhibitor")
                color: Colours.palette.m3onSurfaceVariant
                font: Tokens.font.body.small
                elide: Text.ElideRight
            }
        }

        StyledSwitch {
            Layout.alignment: Qt.AlignVCenter
            checked: IdleInhibitor.enabled
            onToggled: {
                if (IdleInhibitor.enabled !== checked)
                    IdleInhibitor.enabled = checked;
            }
        }
    }
}
