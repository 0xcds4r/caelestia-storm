import QtQuick
import Quickshell
import Quickshell.Wayland
import Caelestia.Config
import qs.components.containers
import qs.services

// Full-screen click-through windows for plugin effects that asked to be drawn above the windows
// (`{"layer": "overlay"}`). The input region is empty, so the desktop below stays clickable; the
// surface sits on the overlay layer, above fullscreen windows too.
Variants {
    model: Screens.screens

    StyledWindow {
        id: win

        required property ShellScreen modelData

        screen: modelData
        name: "effect-overlay"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.exclusionMode: ExclusionMode.Ignore
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        WlrLayershell.mask: Region {}
        color: "transparent"

        anchors.top: true
        anchors.bottom: true
        anchors.left: true
        anchors.right: true

        EffectLayer {
            anchors.fill: parent
            effectLayer: "overlay"
            screenName: win.modelData.name
        }
    }
}
