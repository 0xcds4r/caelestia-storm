pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Caelestia.Config
import qs.components
import qs.services
import qs.utils
import qs.modules.bar.popouts as BarPopouts

Item {
    id: root

    required property ShellScreen screen
    required property ScreenState screenState
    required property BarPopouts.Wrapper popouts
    required property bool fullscreen

    readonly property bool disabled: Strings.testRegexList(Config.bar.excludedScreens, screen.name)
    readonly property bool vertical: BarPos.vertical

    readonly property int clampedWidth: Math.max(Config.border.minThickness, vertical ? implicitWidth : implicitHeight)
    readonly property int padding: Math.max(Tokens.padding.small, Config.border.thickness)
    readonly property int thickness: Tokens.sizes.bar.innerWidth + padding * 2
    readonly property int exclusiveZone: !disabled && (Config.bar.persistent || screenState.bar) ? thickness : Config.border.thickness
    readonly property bool shouldBeVisible: !fullscreen && !disabled && (Config.bar.persistent || screenState.bar || isHovered)
    property bool isHovered

    function closeTray(): void {
        (content.item as Bar)?.closeTray();
    }

    function checkPopout(pos: real): void {
        (content.item as Bar)?.checkPopout(pos);
    }

    function handleWheel(pos: real, angleDelta: point): void {
        (content.item as Bar)?.handleWheel(pos, angleDelta);
    }

    clip: true
    visible: root.vertical ? width > Config.border.thickness : height > Config.border.thickness

    readonly property int hiddenSize: root.fullscreen ? 0 : Config.border.thickness

    implicitWidth: root.vertical ? (root.shouldBeVisible ? root.thickness : root.hiddenSize) : -1
    implicitHeight: root.vertical ? -1 : (root.shouldBeVisible ? root.thickness : root.hiddenSize)

    Behavior on implicitWidth {
        Anim {}
    }

    Behavior on implicitHeight {
        Anim {}
    }

    Loader {
        id: content

        anchors.fill: parent

        active: root.shouldBeVisible

        onLoaded: {
            item.width = Qt.binding(() => root.vertical ? root.thickness : root.width);
            item.height = Qt.binding(() => root.vertical ? root.height : root.thickness);
        }

        sourceComponent: Bar {
            screen: root.screen
            screenState: root.screenState
            popouts: root.popouts // qmllint disable incompatible-type
            fullscreen: root.fullscreen
        }
    }
}
