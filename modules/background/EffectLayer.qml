import QtQuick
import qs.services

// Plugin effects for one screen and one layer. Every effect is a fragment shader
// (`{"type": "shader", "fragment": "..."}`); `layer` picks the surface it is drawn in:
//
//   "background" — on the wallpaper, below every window (default)
//   "overlay"    — in a click-through overlay window above everything, including fullscreen
//
// `monitors` in the descriptor restricts the effect to the listed connectors (empty = every screen).
Item {
    id: root

    property string effectLayer: "background"
    property string screenName: ""

    function matches(effect: var): bool {
        if ((effect.layer ?? "background") !== root.effectLayer)
            return false;

        if (!Plugins.effectOnScreen(effect, root.screenName))
            return false;

        return true;
    }

    Repeater {
        model: Plugins.effects

        delegate: Item {
            id: effectHost

            required property var modelData

            anchors.fill: parent
            visible: effectHost.matches(effectHost.modelData)

            Loader {
                anchors.fill: parent
                active: effectHost.visible
                sourceComponent: shaderComponent

                onLoaded: effectHost.sync(item)
            }

            onModelDataChanged: effectHost.sync(children[0]?.item ?? null)

            function matches(effect: var): bool {
                return root.matches(effect);
            }

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
