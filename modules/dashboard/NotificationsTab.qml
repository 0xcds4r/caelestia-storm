pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Notifications
import Caelestia
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.containers
import qs.components.widgets
import qs.services
import qs.utils

Item {
    id: root

    readonly property var items: Notifs.list.filter(n => !n.closed)
    readonly property int cardWidth: 720

    implicitWidth: root.cardWidth
    implicitHeight: Math.max(220, Math.min(520, column.implicitHeight))

    ColumnLayout {
        id: column

        anchors.fill: parent
        spacing: Tokens.spacing.medium

        RowLayout {
            Layout.fillWidth: true
            spacing: Tokens.spacing.small

            StyledText {
                Layout.fillWidth: true
                Layout.leftMargin: Tokens.padding.medium
                text: Tr.tr("Notifications")
            }

            StyledText {
                text: root.items.length
                color: Colours.palette.m3onSurfaceVariant
            }

            MaterialIcon {
                visible: root.items.length > 0
                text: "clear_all"
                color: Colours.palette.m3onSurfaceVariant

                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -6
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        for (const notif of Notifs.list.slice())
                            notif.close();
                    }
                }
            }
        }

        StyledListView {
            id: list

            Layout.fillWidth: true
            Layout.leftMargin: Tokens.padding.medium
            Layout.fillHeight: true
            implicitWidth: 0
            clip: true
            spacing: Tokens.spacing.medium

            model: ScriptModel {
                values: root.items
            }

            delegate: StyledRect {
                id: card

                required property NotifData modelData

                readonly property bool critical: modelData.urgency === NotificationUrgency.Critical

                width: list.width
                implicitHeight: layout.implicitHeight + Tokens.padding.large * 2
                radius: Tokens.rounding.large
                color: card.critical ? Colours.palette.m3secondaryContainer : Colours.tPalette.m3surfaceContainer

                RowLayout {
                    id: layout

                    anchors.fill: parent
                    anchors.margins: Tokens.padding.large
                    spacing: Tokens.spacing.medium

                    StyledRect {
                        Layout.alignment: Qt.AlignTop
                        implicitWidth: Tokens.sizes.notifs.image
                        implicitHeight: Tokens.sizes.notifs.image
                        radius: Tokens.rounding.full
                        color: card.critical ? Colours.palette.m3error : Colours.palette.m3secondaryContainer

                        Image {
                            anchors.centerIn: parent
                            width: Math.round(parent.width * 0.6)
                            height: width
                            sourceSize.width: width * 2
                            sourceSize.height: height * 2
                            fillMode: Image.PreserveAspectFit
                            visible: card.modelData.appIcon.length > 0
                            source: Quickshell.iconPath(card.modelData.appIcon, "")
                        }

                        MaterialIcon {
                            anchors.centerIn: parent
                            visible: card.modelData.appIcon.length === 0
                            text: Icons.getNotifIcon(card.modelData.summary, card.modelData.urgency)
                            color: card.critical ? Colours.palette.m3onError : Colours.palette.m3onSecondaryContainer
                            fontStyle: Tokens.font.icon.medium
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: Tokens.spacing.small

                            StyledText {
                                Layout.fillWidth: true
                                text: card.modelData.summary
                                maximumLineCount: 1
                                elide: Text.ElideRight
                                color: card.critical ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onSurface
                            }

                            StyledText {
                                text: `• ${card.modelData.timeStr}`
                                color: card.critical ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onSurfaceVariant
                                font: Tokens.font.body.small
                            }
                        }

                        StyledText {
                            Layout.fillWidth: true
                            visible: text.length > 0
                            text: card.modelData.body
                            maximumLineCount: 2
                            elide: Text.ElideRight
                            textFormat: /[<*_`#\[\]]/.test(text) ? Text.MarkdownText : Text.PlainText
                            color: card.critical ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onSurfaceVariant
                            font: Tokens.font.body.small
                        }

                        StyledText {
                            Layout.fillWidth: true
                            visible: text.length > 0 && text !== card.modelData.summary
                            text: card.modelData.appName
                            maximumLineCount: 1
                            elide: Text.ElideRight
                            color: Colours.palette.m3onSurfaceVariant
                            font: Tokens.font.label.small
                        }
                    }

                    MaterialIcon {
                        Layout.alignment: Qt.AlignTop
                        text: "close"
                        color: Colours.palette.m3onSurfaceVariant

                        MouseArea {
                            anchors.fill: parent
                            anchors.margins: -6
                            cursorShape: Qt.PointingHandCursor
                            onClicked: card.modelData.close()
                        }
                    }
                }
            }
        }

        StyledText {
            Layout.alignment: Qt.AlignHCenter
            Layout.fillHeight: true
            visible: root.items.length === 0
            text: Tr.tr("No notifications")
            color: Colours.palette.m3onSurfaceVariant
        }
    }
}
