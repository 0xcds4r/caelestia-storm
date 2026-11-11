pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Caelestia.Config
import qs.components.containers
import qs.services
import qs.modules.bar as Bar

Scope {
    id: root

    required property ShellScreen screen
    required property Bar.BarWrapper bar

    ExclusionZone {
        side: "left"
    }

    ExclusionZone {
        side: "top"
    }

    ExclusionZone {
        side: "right"
    }

    ExclusionZone {
        side: "bottom"
    }

    component ExclusionZone: StyledWindow {
        id: zone

        required property string side

        readonly property bool barSide: BarPos.vertical ? (side === (BarPos.onRight ? "right" : "left")) : (side === (BarPos.onBottom ? "bottom" : "top"))

        screen: root.screen
        name: "border-exclusion"
        anchors.left: side === "left"
        anchors.right: side === "right"
        anchors.top: side === "top"
        anchors.bottom: side === "bottom"
        exclusiveZone: zone.barSide ? root.bar.exclusiveZone : contentItem.Config.border.thickness
        mask: Region {}
        implicitWidth: 1
        implicitHeight: 1
    }
}
