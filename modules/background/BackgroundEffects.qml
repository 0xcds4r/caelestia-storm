import QtQuick
import qs.services

// Background effects contributed by plugins (`effects` command). Rendered on the wallpaper, below
// every window, so the snow falls behind the windows. Every effect is a fragment shader
// (`{"type": "shader", "fragment": "..."}`); the shell only provides time/resolution.
Item {
    id: root

    anchors.fill: parent

    Repeater {
        model: Plugins.effects

        delegate: Item {
            id: effectHost

            required property var modelData

            anchors.fill: parent
            visible: effectHost.modelData.type === "shader"

            Loader {
                anchors.fill: parent
                active: effectHost.visible
                sourceComponent: shaderComponent

                onLoaded: effectHost.sync(item)
            }

            onModelDataChanged: effectHost.sync(children[0]?.item ?? null)

            function sync(item): void {
                if (!item)
                    return;

                item.uniforms = effectHost.modelData.uniforms ?? ({});
                item.timeScale = effectHost.modelData.timeScale ?? 1;
                item.fragment = effectHost.modelData.fragment ?? "";
            }
        }
    }

    Component {
        id: shaderComponent

        PluginShader {
            anchors.fill: parent
        }
    }
}
