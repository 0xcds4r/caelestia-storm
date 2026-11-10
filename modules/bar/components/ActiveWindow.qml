pragma ComponentBehavior: Bound

import QtQuick
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.services
import qs.utils

Item {
    id: root

    required property var bar
    required property Brightness.Monitor monitor
    property color colour: Colours.palette.m3primary

    readonly property bool vertical: BarPos.vertical

    readonly property string windowTitle: {
        const title = Hypr.activeToplevel?.title;
        if (!title)
            return Tr.trCtx("Desktop", "shown when no window is focused");
        if (Config.bar.activeWindow.compact) {
            // " - " (standard hyphen), " — " (em dash), " – " (en dash)
            const parts = title.split(/\s+[\-\u2013\u2014]\s+/);
            if (parts.length > 1)
                return parts[parts.length - 1].trim();
        }
        return title;
    }

    readonly property var otherModules: bar.children.filter(c => c.entryId && c.item !== this && c.entryId !== "spacer")

    readonly property int maxLength: {
        const used = root.otherModules.reduce((acc, curr) => acc + (root.vertical ? (curr.item.nonAnimHeight ?? curr.height) : (curr.item.nonAnimWidth ?? curr.width)), 0);
        const total = root.vertical ? bar.height : bar.width;
        const spacing = root.bar.spacing * (bar.children.length - 1);
        const padding = root.bar.vPadding * 2;
        return total - used - spacing - padding;
    }

    property Title current: text1

    clip: true
    implicitWidth: root.vertical ? Math.max(icon.implicitWidth, current.implicitHeight) : icon.implicitWidth + Tokens.spacing.small + current.implicitWidth
    implicitHeight: root.vertical ? icon.implicitHeight + current.implicitWidth + current.anchors.topMargin : Math.max(icon.implicitHeight, current.implicitHeight)

    Loader {
        asynchronous: true
        anchors.fill: parent
        active: !Config.bar.activeWindow.showOnHover

        sourceComponent: MouseArea {
            cursorShape: Qt.PointingHandCursor
            hoverEnabled: true
            onPositionChanged: {
                const popouts = root.bar.popouts;
                if (popouts.hasCurrent && popouts.currentName !== "activewindow")
                    popouts.hasCurrent = false;
            }
            onClicked: {
                const popouts = root.bar.popouts;
                if (popouts.hasCurrent) {
                    popouts.hasCurrent = false;
                } else {
                    popouts.currentName = "activewindow";
                    popouts.currentCenter = root.vertical ? root.mapToItem(root.bar, 0, root.implicitHeight / 2).y : root.mapToItem(root.bar, root.implicitWidth / 2, 0).x;
                    popouts.hasCurrent = true;
                }
            }
        }
    }

    MaterialIcon {
        id: icon

        anchors.horizontalCenter: root.vertical ? parent.horizontalCenter : undefined
        anchors.verticalCenter: root.vertical ? undefined : parent.verticalCenter
        anchors.left: root.vertical ? undefined : parent.left

        animate: true
        text: Icons.getAppCategoryIcon(Hypr.activeToplevel?.lastIpcObject.class, "desktop_windows")
        color: root.colour
    }

    Title {
        id: text1
    }

    Title {
        id: text2
    }

    TextMetrics {
        id: metrics

        text: root.windowTitle
        font: root.Tokens.font.body.builders.small.letterSpacing(1.4).build()
        elide: Qt.ElideRight
        elideWidth: root.vertical ? root.maxLength - icon.height : root.maxLength - icon.width - Tokens.spacing.small

        onTextChanged: {
            const next = root.current === text1 ? text2 : text1;
            next.text = elidedText;
            root.current = next;
        }
        onElideWidthChanged: root.current.text = elidedText
    }

    Behavior on implicitHeight {
        Anim {}
    }

    Behavior on implicitWidth {
        Anim {}
    }

    component Title: StyledText {
        id: text

        anchors.horizontalCenter: icon.horizontalCenter
        anchors.top: root.vertical ? icon.bottom : undefined
        anchors.topMargin: root.vertical ? Tokens.spacing.small : 0
        anchors.verticalCenter: root.vertical ? undefined : parent.verticalCenter
        anchors.left: root.vertical ? undefined : icon.right
        anchors.leftMargin: root.vertical ? 0 : Tokens.spacing.small

        font: metrics.font
        color: root.colour
        opacity: root.current === this ? 1 : 0
        horizontalAlignment: Text.AlignLeft

        width: root.vertical ? implicitHeight : implicitWidth
        height: root.vertical ? implicitWidth : implicitHeight

        transform: [
            Translate {
                x: root.vertical && root.Config.bar.activeWindow.inverted ? -text.implicitWidth + text.implicitHeight : 0
            },
            Rotation {
                angle: root.vertical ? (root.Config.bar.activeWindow.inverted ? 270 : 90) : 0
                origin.x: root.vertical ? text.implicitHeight / 2 : 0
                origin.y: root.vertical ? text.implicitHeight / 2 : 0
            }
        ]

        Behavior on opacity {
            Anim {
                type: Anim.DefaultEffects
            }
        }
    }
}
