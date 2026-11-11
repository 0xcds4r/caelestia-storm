pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.components
import qs.services
import qs.modules.bar.popouts // Need to import this module so the Wrapper type is the same as others

Item {
    id: root

    required property ShellScreen screen
    required property real borderThickness

    readonly property alias content: content
    readonly property bool vertical: BarPos.vertical
    property real offsetScale: (root.vertical ? x > 0 : y > 0) || content.hasCurrent ? 0 : 1

    visible: width > 0 && height > 0
    clip: true

    implicitWidth: root.vertical ? content.implicitWidth * (1 - offsetScale) : content.implicitWidth
    implicitHeight: root.vertical ? content.implicitHeight : content.implicitHeight * (1 - offsetScale)

    // The popout background is a bit wider than the content (see popoutBg in ContentWindow.qml),
    // split evenly on each side. Keep that whole shape on screen so the content stays centred.
    readonly property real sidePad: root.vertical ? 0 : content.nonAnimWidth * 0.03

    x: {
        if (content.isDetached)
            return (parent.width - content.nonAnimWidth) / 2;
        if (root.vertical)
            return 0;

        const off = content.currentCenter - content.nonAnimWidth / 2;
        return Math.max(Math.min(off, parent.width - content.nonAnimWidth - sidePad), sidePad);
    }

    y: {
        if (content.isDetached)
            return (parent.height - content.nonAnimHeight) / 2;
        if (!root.vertical)
            return 0;

        const off = content.currentCenter - borderThickness - content.nonAnimHeight / 2;
        const diff = parent.height - Math.floor(off + content.nonAnimHeight);
        if (diff < 0)
            return off + diff;
        return Math.max(off, 0);
    }

    Behavior on offsetScale {
        Anim {}
    }

    Behavior on x {
        Anim {
            duration: content.animLength
            easing: content.animCurve
        }
    }

    Behavior on y {
        enabled: root.offsetScale < 1

        Anim {
            duration: content.animLength
            easing: content.animCurve
        }
    }

    Wrapper {
        id: content

        screen: root.screen
        offsetScale: root.offsetScale

        y: root.vertical ? (parent.height - height) / 2 : (-root.implicitHeight - 5) * root.offsetScale
        anchors.left: parent.left
        anchors.leftMargin: root.vertical ? (-implicitWidth - 5) * root.offsetScale : 0
    }
}
