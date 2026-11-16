import QtQuick
import Quickshell

// A fragment shader contributed by a plugin:
//
//   {"type": "shader", "id": "plasma", "fragment": "plasma.frag.qsb",
//    "uniforms": {"speed": 1.0, "tint": "#ff8800", "size": [4, 2]}}
//
// The shader has to be baked for Qt's RHI (`qsb --qt6`); the path is relative to the plugin's own
// directory. The shell always provides `time` (seconds) and `resolution` (pixels); everything else
// comes from `uniforms` (number, bool, "#rrggbb" colour or a 2–4 element array).
Item {
    id: root

    property string fragment: ""
    property var uniforms: ({})
    property real timeScale: 1
    // 1 = render at native size; 0.5 renders a quarter of the pixels and scales up (cheap, softer)
    property real renderScale: 1
    // a full-screen shader on the overlay layer is recomposited by the compositor on every frame,
    // so the effect is only pushed at this rate by default
    property real fps: 30

    property real elapsed: 0
    property real wallTime: 0
    property real pushedAt: 0

    // signature of the compiled effect, so a reload only rebuilds when the shader really changed
    readonly property string signature: {
        const names = [];
        const source = root.uniforms ?? {};

        for (const key of Object.keys(source)) {
            const value = source[key];
            let kind = "?";

            if (typeof value === "number")
                kind = "n";
            else if (typeof value === "boolean")
                kind = "b";
            else if (typeof value === "string")
                kind = "c";
            else if (Array.isArray(value))
                kind = `v${value.length}`;

            names.push(`${key}:${kind}`);
        }

        return `${root.fragment}|${names.sort().join(",")}`;
    }

    onSignatureChanged: root.build()
    onFragmentChanged: root.build()
    // same uniform names, new values: no rebuild needed, just write them through
    onUniformsChanged: root.applyUniforms()

    Component.onCompleted: root.build()

    FrameAnimation {
        running: root.visible && root.fragment.length > 0

        onTriggered: {
            const step = Math.min(frameTime, 0.1);

            root.elapsed += step * root.timeScale;
            root.wallTime += step;

            if (root.fps > 0 && root.wallTime - root.pushedAt < 1 / root.fps)
                return;

            root.pushedAt = root.wallTime;
            root.update();
        }
    }

    Item {
        id: host

        anchors.fill: parent

        onWidthChanged: root.update()
        onHeightChanged: root.update()
    }

    property var shaderItem: null
    property string builtSignature: ""

    function removeShader(): void {
        if (root.shaderItem) {
            root.shaderItem.destroy();
            root.shaderItem = null;
        }
    }

    function build(): void {
        if (root.builtSignature === root.signature && root.shaderItem)
            return;

        root.removeShader();
        root.builtSignature = root.signature;

        if (!root.fragment)
            return;

        const scale = Math.max(0.25, Math.min(1, root.renderScale));
        const lines = [
            "import QtQuick",
            "ShaderEffect {",
            `width: Math.max(1, Math.round(parent.width * ${scale}))`,
            `height: Math.max(1, Math.round(parent.height * ${scale}))`,
            `scale: ${1 / scale}`,
            "transformOrigin: Item.TopLeft",
            "property real time: 0",
            "property vector2d resolution: Qt.vector2d(1, 1)"
        ];
        const source = root.uniforms ?? {};

        for (const key of Object.keys(source)) {
            if (!/^[A-Za-z_][A-Za-z0-9_]*$/.test(key) || key === "time" || key === "resolution")
                continue;

            const value = source[key];

            if (typeof value === "number")
                lines.push(`property real ${key}: ${value}`);
            else if (typeof value === "boolean")
                lines.push(`property bool ${key}: ${value}`);
            else if (typeof value === "string" && value.startsWith("#"))
                lines.push(`property color ${key}: "${value}"`);
            else if (Array.isArray(value) && value.length >= 2 && value.length <= 4) {
                const type = ["vector2d", "vector3d", "vector4d"][value.length - 2];
                lines.push(`property ${type} ${key}: Qt.${type}(${value.map(Number).join(", ")})`);
            }
        }

        lines.push(`fragmentShader: "${root.fragment}"`);
        lines.push("}");

        try {
            root.shaderItem = Qt.createQmlObject(lines.join("\n"), host, "plugin-shader");
        } catch (error) {
            console.warn(`plugin shader ${root.fragment}: ${error}`);
            return;
        }

        root.applyUniforms();
        root.update();
    }

    function applyUniforms(): void {
        if (!root.shaderItem)
            return;

        const source = root.uniforms ?? {};

        for (const key of Object.keys(source)) {
            if (!/^[A-Za-z_][A-Za-z0-9_]*$/.test(key) || key === "time" || key === "resolution")
                continue;

            const value = source[key];

            // the effect may still be the previous build (uniforms arrive after the fragment)
            if (root.shaderItem[key] === undefined)
                continue;

            if (Array.isArray(value) && value.length >= 2 && value.length <= 4) {
                const type = ["vector2d", "vector3d", "vector4d"][value.length - 2];
                root.shaderItem[key] = Qt[type](value[0], value[1], value[2] ?? 0, value[3] ?? 0);
            } else if (typeof value === "number" || typeof value === "boolean" || typeof value === "string") {
                root.shaderItem[key] = value;
            }
        }
    }

    function update(): void {
        if (!root.shaderItem)
            return;

        root.shaderItem.time = root.elapsed;
        root.shaderItem.resolution = Qt.vector2d(root.shaderItem.width, root.shaderItem.height);
    }
}
