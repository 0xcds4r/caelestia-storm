import QtQuick
import qs.services

// Background effects contributed by plugins (`effects` command). Rendered on the wallpaper, below
// every window, so the snow falls behind the windows.
Item {
    id: root

    anchors.fill: parent

    Repeater {
        model: Plugins.effects

        delegate: Snow {
            required property var modelData

            anchors.fill: parent

            visible: modelData.type === "snow"
            density: modelData.type === "snow" ? (modelData.density ?? 1) : 0
            wind: modelData.wind ?? 0
            speed: modelData.speed ?? 1
            flakeSize: modelData.size ?? 1
            strength: modelData.opacity ?? 1
        }
    }
}
