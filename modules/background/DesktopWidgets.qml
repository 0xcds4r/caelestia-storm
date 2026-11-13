pragma ComponentBehavior: Bound

import QtQuick
import Caelestia.Config
import qs.components
import qs.services

// Desktop widgets contributed by plugins (`desktop` command). Rendered on the wallpaper, below
// every window; purely informational, they do not take input.
Item {
    id: root

    anchors.fill: parent

    Repeater {
        model: Plugins.desktopWidgets

        delegate: StyledRect {
            id: card

            required property var modelData

            readonly property int margin: modelData.margin ?? 64
            readonly property bool anchored: (modelData.anchor ?? "").length > 0

            visible: modelData.text !== undefined
            x: {
                switch (modelData.anchor) {
                case "top-right":
                case "bottom-right":
                    return root.width - width - card.margin;
                case "center":
                    return (root.width - width) / 2;
                default:
                    return card.anchored ? card.margin : (modelData.x ?? 64);
                }
            }
            y: {
                switch (modelData.anchor) {
                case "bottom-left":
                case "bottom-right":
                    return root.height - height - card.margin;
                case "center":
                    return (root.height - height) / 2;
                default:
                    return card.anchored ? card.margin : (modelData.y ?? 64);
                }
            }

            implicitWidth: modelData.width ?? 260
            implicitHeight: cardColumn.implicitHeight + Tokens.padding.largeIncreased * 2

            radius: Tokens.rounding.large
            color: Qt.alpha(Colours.tPalette.m3surfaceContainer, 0.72)

            Column {
                id: cardColumn

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.margins: Tokens.padding.largeIncreased
                spacing: Tokens.spacing.extraSmall

                Row {
                    spacing: Tokens.spacing.small

                    MaterialIcon {
                        visible: (card.modelData.icon ?? "").length > 0
                        anchors.verticalCenter: parent.verticalCenter
                        text: card.modelData.icon ?? ""
                        color: Colours.palette.m3primary
                        fontStyle: Tokens.font.icon.small
                    }

                    StyledText {
                        anchors.verticalCenter: parent.verticalCenter
                        text: card.modelData.title ?? ""
                        color: Colours.palette.m3onSurfaceVariant
                        font: Tokens.font.label.medium
                    }
                }

                StyledText {
                    text: card.modelData.text ?? ""
                    color: Colours.palette.m3onSurface
                    font: Tokens.font.headline.medium
                }

                StyledText {
                    visible: (card.modelData.subtext ?? "").length > 0
                    text: card.modelData.subtext ?? ""
                    color: Colours.palette.m3onSurfaceVariant
                    font: Tokens.font.body.small
                }
            }
        }
    }
}
