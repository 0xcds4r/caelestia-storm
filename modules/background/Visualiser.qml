pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import Quickshell
import Caelestia.Components
import Caelestia.Config
import Caelestia.Services
import qs.components
import qs.services

Item {
    id: root

    required property ShellScreen screen
    required property Item wallpaper

    // Cava keeps emitting frames even in silence, so the bars were repainting the whole wallpaper
    // around the clock (~13 % of the GPU on a 1080p screen). The visualiser now only exists while
    // something is actually audible.
    readonly property bool sounding: Audio.cava.values.some(value => value > 0.01)
    property bool audible: false

    onSoundingChanged: {
        if (sounding) {
            audible = true;
            silenceTimer.stop();
        } else {
            silenceTimer.restart();
        }
    }

    Timer {
        id: silenceTimer

        interval: 2000
        repeat: false

        onTriggered: root.audible = false
    }

    readonly property bool shouldBeActive: Config.background.visualiser.enabled && audible && (!Config.background.visualiser.autoHide || (Hypr.monitorFor(screen)?.activeWorkspace?.toplevels?.values.every(t => t.lastIpcObject?.floating) ?? true))
    property real offset: shouldBeActive ? 0 : screen.height * 0.2

    opacity: shouldBeActive ? 1 : 0

    Loader {
        asynchronous: true
        anchors.fill: parent
        active: root.opacity > 0 && Config.background.visualiser.blur

        sourceComponent: MultiEffect {
            source: root.wallpaper
            maskSource: wrapper
            maskEnabled: true
            blurEnabled: true
            blur: 1
            blurMax: 32
            autoPaddingEnabled: false
        }
    }

    Item {
        id: wrapper

        anchors.fill: parent
        layer.enabled: true

        Loader {
            asynchronous: true
            anchors.fill: parent
            anchors.topMargin: root.offset
            anchors.bottomMargin: -root.offset

            active: root.opacity > 0

            sourceComponent: Item {
                ServiceRef {
                    service: Audio.cava
                }

                VisualiserBars {
                    id: bars

                    anchors.fill: parent
                    anchors.margins: Config.border.thickness
                    anchors.leftMargin: (ShellState.componentsFor(root.screen)?.bar?.exclusiveZone ?? 0) + Tokens.spacing.small * Config.background.visualiser.spacing

                    values: Audio.cava.values
                    primaryColor: Qt.alpha(Colours.palette.m3primary, 0.7)
                    secondaryColor: Qt.alpha(Colours.palette.m3inversePrimary, 0.7)
                    rounding: Tokens.rounding.medium * Config.background.visualiser.rounding
                    spacing: Tokens.spacing.extraSmall * Config.background.visualiser.spacing
                    animationDuration: Tokens.anim.durations.normal

                    Behavior on anchors.leftMargin {
                        Anim {}
                    }
                }

                FrameAnimation {
                    running: root.opacity > 0 && !bars.settled
                    onTriggered: bars.advance(frameTime)
                }
            }
        }
    }

    Behavior on offset {
        Anim {}
    }

    Behavior on opacity {
        Anim {
            type: Anim.DefaultEffects
        }
    }
}
