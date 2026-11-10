pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Caelestia
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.containers
import qs.components.widgets
import qs.services
import qs.modules.notifications as Notifications

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
            Layout.fillHeight: true
            clip: true
            spacing: Tokens.spacing.medium

            model: ScriptModel {
                values: root.items
            }

            delegate: Notifications.Notification {
                width: list.width
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
