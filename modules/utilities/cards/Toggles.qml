pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell.Bluetooth
import Caelestia.Components
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.controls
import qs.services
import qs.utils
import qs.modules.nexus
import qs.modules.bar.popouts as BarPopouts

StyledRect {
    id: root

    required property ScreenState screenState
    required property BarPopouts.Wrapper popouts

    readonly property var quickToggles: {
        const seenIds = new Set();

        return Config.utilities.quickToggles.values.filter(item => {
            if (!item.enabled)
                return false;

            if (seenIds.has(item.id)) {
                return false;
            }

            if (item.id === "vpn") {
                return GlobalConfig.utilities.vpn.selectedProvider.length > 0;
            }

            seenIds.add(item.id);
            return true;
        });
    }
    readonly property int splitIndex: Math.ceil(quickToggles.length / 2)
    readonly property var monitor: Brightness.getMonitorForScreen(root.screenState.modelData)
    readonly property bool needExtraRow: quickToggles.length > 6

    property real minHeight: 0

    implicitHeight: Math.max(layout.implicitHeight + Tokens.padding.extraLargeIncreased, root.minHeight)

    radius: Tokens.rounding.large
    color: Colours.tPalette.m3surfaceContainer

    ColumnLayout {
        id: layout

        anchors.fill: parent
        anchors.margins: Tokens.padding.large
        spacing: Tokens.spacing.medium

        StyledText {
            text: Tr.tr("Quick toggles")
            font: Tokens.font.body.medium
        }

        QuickToggleRow {
            model: root.needExtraRow ? root.quickToggles.slice(0, root.splitIndex) : root.quickToggles
        }

        QuickToggleRow {
            visible: root.needExtraRow
            model: root.needExtraRow ? root.quickToggles.slice(root.splitIndex) : []
        }

        // Local patch: volume + brightness live in the quick toggles card
        CustomMouseArea {
            Layout.fillWidth: true
            implicitHeight: Tokens.padding.large * 2

            onWheel: event => {
                if (event.angleDelta.y > 0)
                    Audio.incrementVolume();
                else if (event.angleDelta.y < 0)
                    Audio.decrementVolume();
            }

            RowLayout {
                anchors.fill: parent
                spacing: Tokens.spacing.medium

                MaterialIcon {
                    id: volumeIcon

                    Layout.alignment: Qt.AlignVCenter
                    text: Icons.getVolumeIcon(Audio.volume, Audio.muted)
                    color: Colours.palette.m3onSurfaceVariant

                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -4
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Audio.toggleMute()
                    }
                }

                StyledSlider {
                    Layout.fillWidth: true
                    implicitHeight: parent.height - Tokens.padding.medium

                    value: Audio.volume
                    onInteraction: value => Audio.setVolume(value)
                }

                StyledText {
                    text: `${Math.round(Audio.volume * 100)}%`
                    color: Colours.palette.m3onSurfaceVariant
                    font: Tokens.font.body.builders.medium.weight(Font.Medium).build()
                }
            }
        }

        CustomMouseArea {
            Layout.fillWidth: true
            implicitHeight: Tokens.padding.large * 2

            onWheel: event => {
                if (!root.monitor)
                    return;
                if (event.angleDelta.y > 0)
                    root.monitor.setBrightness(root.monitor.brightness + GlobalConfig.services.brightnessIncrement);
                else if (event.angleDelta.y < 0)
                    root.monitor.setBrightness(root.monitor.brightness - GlobalConfig.services.brightnessIncrement);
            }

            RowLayout {
                anchors.fill: parent
                spacing: Tokens.spacing.medium

                MaterialIcon {
                    Layout.alignment: Qt.AlignVCenter
                    text: `brightness_${(Math.round((root.monitor?.brightness ?? 0) * 6) + 1)}`
                    color: Colours.palette.m3onSurfaceVariant
                }

                StyledSlider {
                    Layout.fillWidth: true
                    implicitHeight: parent.height - Tokens.padding.medium

                    value: root.monitor?.brightness ?? 0
                    onInteraction: value => root.monitor?.setBrightness(value)
                }

                StyledText {
                    text: `${Math.round((root.monitor?.brightness ?? 0) * 100)}%`
                    color: Colours.palette.m3onSurfaceVariant
                    font: Tokens.font.body.builders.medium.weight(Font.Medium).build()
                }
            }
        }
    }

    component QuickToggleRow: ButtonRow {
        property alias model: repeater.model

        Layout.fillWidth: true
        spacing: Tokens.spacing.small

        Repeater {
            id: repeater

            delegate: DelegateChooser {
                role: "id"

                DelegateChoice {
                    roleValue: "wifi"
                    delegate: Toggle {
                        icon: "wifi"
                        checked: Nmcli.wifiEnabled
                        onClicked: Nmcli.toggleWifi()
                    }
                }
                DelegateChoice {
                    roleValue: "bluetooth"
                    delegate: Toggle {
                        icon: "bluetooth"
                        checked: Bluetooth.defaultAdapter?.enabled ?? false // qmllint disable unresolved-type
                        onClicked: {
                            const adapter = Bluetooth.defaultAdapter; // qmllint disable unresolved-type
                            if (adapter)
                                adapter.enabled = !adapter.enabled;
                        }
                    }
                }
                DelegateChoice {
                    roleValue: "mic"
                    delegate: Toggle {
                        icon: "mic"
                        checked: !Audio.sourceMuted
                        onClicked: {
                            const audio = Audio.source?.audio;
                            if (audio)
                                audio.muted = !audio.muted;
                        }
                    }
                }
                DelegateChoice {
                    roleValue: "settings"
                    delegate: Toggle {
                        icon: "settings"
                        inactiveOnColour: Colours.palette.m3onSurfaceVariant
                        isToggle: false
                        onClicked: {
                            root.screenState.utilities = false;
                            WindowFactory.create();
                        }
                    }
                }
                DelegateChoice {
                    roleValue: "gameMode"
                    delegate: Toggle {
                        icon: "gamepad"
                        checked: GameMode.enabled
                        onClicked: GameMode.enabled = !GameMode.enabled
                    }
                }
                DelegateChoice {
                    roleValue: "dnd"
                    delegate: Toggle {
                        icon: "notifications_off"
                        checked: Notifs.dnd
                        onClicked: Notifs.dnd = !Notifs.dnd
                    }
                }
                DelegateChoice {
                    roleValue: "vpn"
                    delegate: Toggle {
                        icon: "vpn_key"
                        checked: VPN.connected && VPN.status.state !== "needs-auth" && VPN.status.state !== "error"
                        enabled: !VPN.connecting && !VPN.disconnecting
                        isToggle: VPN.status.state !== "needs-auth" && VPN.status.state !== "error"
                        inactiveOnColour: Colours.palette.m3onSurfaceVariant
                        onClicked: VPN.toggle()
                    }
                }
            }
        }
    }

    component Toggle: IconButton {
        inactiveColour: Colours.layer(Colours.palette.m3surfaceContainerHighest, 2)
        fillWidth: true
        isToggle: true
        isRound: true
        shapeMorph: true
    }
}
