import QtQuick
import qs.services

// Background effects contributed by plugins (`effects` command). Rendered on the wallpaper, below
// every window, so the snow falls behind the windows.
Item {
    id: root

    anchors.fill: parent

    Repeater {
        model: Plugins.effects

        delegate: Item {
            id: effectHost

            required property var modelData

            anchors.fill: parent
            visible: effectHost.modelData.type === "snow" || effectHost.modelData.type === "shader"

            Loader {
                anchors.fill: parent
                active: effectHost.visible
                sourceComponent: effectHost.modelData.type === "snow" ? snowComponent : shaderComponent

                onLoaded: effectHost.sync(item)
            }

            onModelDataChanged: effectHost.sync(children[0]?.item ?? null)

            function sync(item): void {
                if (!item)
                    return;

                if (effectHost.modelData.type === "snow") {
                    item.density = effectHost.modelData.density ?? 1;
                    item.wind = effectHost.modelData.wind ?? 0;
                    item.speed = effectHost.modelData.speed ?? 1;
                    item.flakeSize = effectHost.modelData.size ?? 1;
                    item.strength = effectHost.modelData.opacity ?? 1;
                    return;
                }

                item.uniforms = effectHost.modelData.uniforms ?? ({});
                item.timeScale = effectHost.modelData.timeScale ?? 1;
                item.fragment = effectHost.modelData.fragment ?? "";
            }
        }
    }

    Component {
        id: snowComponent

        Snow {
            anchors.fill: parent
        }
    }

    Component {
        id: shaderComponent

        PluginShader {
            anchors.fill: parent
        }
    }
}
