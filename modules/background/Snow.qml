import QtQuick
import Quickshell

// Procedural snowfall, driven by a plugin `effects` descriptor (`{"type": "snow", ...}`).
//
// The flakes are generated in the fragment shader (`shaders/snow.frag`, baked to `.qsb`): three
// layers of hash-based cells, each flake falling and wrapping inside its own cell. That keeps a few
// thousand flakes cheap and lets density / wind / speed change without rebuilding anything.
//
// Rebuild the shader after editing the source:
//   /usr/lib/qt6/bin/qsb --qt6 -o snow.frag.qsb snow.frag
Item {
    id: root

    property real density: 1
    property real wind: 0
    property real speed: 1
    property real flakeSize: 1
    property real strength: 1

    property real elapsed: 0

    FrameAnimation {
        running: root.visible && root.density > 0

        onTriggered: root.elapsed += Math.min(frameTime, 0.1) * root.speed
    }

    ShaderEffect {
        anchors.fill: parent

        property real time: root.elapsed
        property vector2d resolution: Qt.vector2d(width, height)
        property real density: Math.max(0, Math.min(1, root.density))
        property real wind: Math.max(-1, Math.min(1, root.wind))
        property real flakeSize: root.flakeSize
        property real strength: root.strength

        fragmentShader: "shaders/snow.frag.qsb"
    }
}
