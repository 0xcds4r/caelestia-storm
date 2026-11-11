pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Caelestia.Config
import qs.modules.bar as Bar
import qs.services

Region {
    id: root

    required property Bar.BarWrapper bar
    required property Panels panels
    required property var win

    readonly property real borderThickness: win.contentItem.Config.border.thickness
    readonly property real clampedThickness: win.contentItem.Config.border.clampedThickness

    // The mask is XOR'd with the window (see ContentWindow.qml), so the base region describes
    // where clicks pass through. The bar's own edge must stay outside of it, otherwise the whole
    // bar becomes click-through (very noticeable on an empty workspace, where dragMaskPadding
    // is at its largest).
    readonly property real pad: win.dragMaskPadding
    readonly property real edge: clampedThickness
    readonly property real barSide: bar.clampedWidth
    readonly property real leftInset: bar.vertical && !BarPos.onRight ? barSide + pad : edge + pad
    readonly property real topInset: !bar.vertical && !BarPos.onBottom ? barSide + pad : edge + pad
    readonly property real rightInset: bar.vertical && BarPos.onRight ? barSide + pad : edge + pad
    readonly property real bottomInset: !bar.vertical && BarPos.onBottom ? barSide + pad : edge + pad

    x: leftInset
    y: topInset
    width: win.width - leftInset - rightInset
    height: win.height - topInset - bottomInset
    intersection: Intersection.Xor

    R {
        panel: root.panels.dashboard
        y: 0
        height: panel.height * (1 - root.panels.dashboard.offsetScale) + root.borderThickness
    }

    R {
        panel: root.panels.launcher
        y: root.win.height - height
        height: panel.height * (1 - root.panels.launcher.offsetScale) + root.borderThickness
    }

    R {
        id: sessionRegion

        panel: root.panels.sessionWrapper
        x: root.win.width - width
        width: panel.width * (1 - root.panels.session.offsetScale) + root.borderThickness + sidebarRegion.width
    }

    R {
        id: sidebarRegion

        panel: root.panels.sidebar
        x: root.win.width - width
        width: panel.width * (1 - root.panels.sidebar.offsetScale) + root.borderThickness
    }

    R {
        panel: root.panels.osdWrapper
        x: root.win.width - width
        width: panel.width * (1 - root.panels.osd.offsetScale) + root.borderThickness + sessionRegion.width
    }

    R {
        panel: root.panels.notifications
        y: 0
        height: panel.height + root.borderThickness
    }

    R {
        panel: root.panels.utilities
        y: root.win.height - height
        height: panel.height * (1 - root.panels.utilities.offsetScale) + root.borderThickness
    }

    R {
        panel: root.panels.popoutsWrapper
        width: panel.width * (1 - root.panels.popoutsWrapper.offsetScale)
    }

    component R: Region {
        required property Item panel

        x: panel.x + (root.bar.vertical ? root.bar.implicitWidth : 0)
        y: panel.y + (root.bar.vertical ? root.borderThickness : root.bar.implicitHeight)
        width: panel.width
        height: panel.height
        intersection: Intersection.Subtract
    }
}
