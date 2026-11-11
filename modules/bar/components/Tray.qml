pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.SystemTray
import Caelestia.Config
import qs.components
import qs.services

StyledRect {
    id: root

    readonly property alias layout: layout
    readonly property alias items: items
    readonly property alias expandIcon: expandIcon

    readonly property bool vertical: BarPos.vertical
    // The compact (collapsed) tray only makes sense on a vertical bar; in a horizontal
    // one the icons overflow the reserved width and overlap the neighbouring entries.
    readonly property bool compact: Config.bar.tray.compact && root.vertical
    readonly property int padding: Config.bar.tray.background ? Tokens.padding.medium : Tokens.padding.extraSmall
    readonly property int spacing: Config.bar.tray.background ? Tokens.spacing.medium : Tokens.spacing.extraSmall

    property bool expanded

    readonly property real nonAnimThickness: {
        const length = root.vertical ? layout.implicitHeight : layout.implicitWidth;
        const expand = root.vertical ? expandIcon.implicitHeight : expandIcon.implicitWidth;

        if (!root.compact)
            return length + padding * 2;

        const pad = (Config.bar.tray.background ? Tokens.padding.extraSmall : 0) + padding;
        if (expanded)
            return expand + length + spacing + pad;

        return Math.max(Config.bar.tray.background ? (root.vertical ? width : height) : 0, expand + pad);
    }

    clip: true
    visible: root.vertical ? height > 0 : width > 0

    implicitWidth: root.vertical ? Tokens.sizes.bar.innerWidth : root.nonAnimThickness
    implicitHeight: root.vertical ? root.nonAnimThickness : Tokens.sizes.bar.innerWidth

    color: Qt.alpha(Colours.tPalette.m3surfaceContainer, (Config.bar.tray.background && items.count > 0) ? Colours.tPalette.m3surfaceContainer.a : 0)
    radius: Tokens.rounding.full

    GridLayout {
        id: layout

        // Plain geometry instead of conditional anchors: `undefined` does not detach an anchor at
        // runtime, which broke the layout when the bar changed orientation.
        x: root.vertical ? (root.width - width) / 2 : root.padding
        y: root.vertical ? root.padding : (root.height - height) / 2

        columns: root.vertical ? 1 : -1
        rows: root.vertical ? -1 : 1
        rowSpacing: Tokens.spacing.small
        columnSpacing: Tokens.spacing.small

        opacity: root.expanded || !root.compact ? 1 : 0

        Repeater {
            id: items

            model: ScriptModel {
                values: SystemTray.items.values.filter(i => i.status !== Status.Passive && !GlobalConfig.bar.tray.hiddenIcons.includes(i.id))
            }

            TrayItem {}
        }

        Behavior on opacity {
            Anim {
                type: Anim.DefaultEffects
            }
        }
    }

    Loader {
        id: expandIcon

        asynchronous: true

        x: root.vertical ? (root.width - width) / 2 : root.width - width
        y: root.vertical ? root.height - height : (root.height - height) / 2

        active: root.compact && items.count > 0

        sourceComponent: Item {
            implicitWidth: expandIconInner.implicitWidth
            implicitHeight: expandIconInner.implicitHeight - Tokens.padding.small

            MaterialIcon {
                id: expandIconInner

                x: root.vertical ? (parent.width - width) / 2 : parent.width - width - (Config.bar.tray.background ? Tokens.padding.extraSmall : -Tokens.padding.small)
                y: root.vertical ? parent.height - height - (Config.bar.tray.background ? Tokens.padding.extraSmall : -Tokens.padding.small) : (parent.height - height) / 2
                text: "expand_less"
                color: Colours.palette.m3onSurfaceVariant
                fontStyle: Tokens.font.icon.medium
                rotation: root.vertical ? (root.expanded ? 180 : 0) : (root.expanded ? 90 : -90)

                Behavior on rotation {
                    Anim {}
                }

                Behavior on y {
                    Anim {}
                }
            }
        }
    }

    Behavior on implicitHeight {
        Anim {}
    }

    Behavior on implicitWidth {
        Anim {}
    }
}
