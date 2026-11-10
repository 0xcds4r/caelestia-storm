pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import M3Shapes
import Caelestia.Components
import Caelestia.Config
import qs.components
import qs.services
import qs.utils

Item {
    id: root

    required property int modelData
    required property int index
    required property int activeWsId
    required property int ws
    required property HyprlandMonitor monitor

    required property int displayType
    required property bool showWindows
    required property var iconRules
    property string activeLabel
    property string occupiedLabel
    property string label

    readonly property list<HyprlandToplevel> toplevels: Hypr.toplevelsForWs(ws, GlobalConfig.bar.workspaces.ignoredTags)
    readonly property bool isOccupied: toplevels.length > 0
    // Local patch: one cell per workspace, the app icon replaces the shape when occupied
    readonly property bool hasWindows: false
    readonly property HyprlandToplevel iconToplevel: {
        const act = Hypr.activeToplevel;
        if (focused && act && toplevels.includes(act))
            return act;
        return toplevels[toplevels.length - 1] ?? null;
    }
    readonly property string appIcon: {
        const t = iconToplevel;
        if (!t)
            return "";
        return Icons.getAppIcon(t.lastIpcObject.class, "application-x-executable");
    }
    readonly property bool focused: activeWsId === ws
    readonly property list<int> focusedShapeList: [MaterialShape.Slanted, MaterialShape.Oval, MaterialShape.Pill, MaterialShape.Triangle, MaterialShape.Arrow, MaterialShape.Diamond, MaterialShape.Pentagon, MaterialShape.Gem, MaterialShape.VerySunny, MaterialShape.Sunny, MaterialShape.Cookie4Sided, MaterialShape.Cookie6Sided, MaterialShape.Cookie7Sided, MaterialShape.Cookie9Sided, MaterialShape.Cookie12Sided, MaterialShape.Clover4Leaf, MaterialShape.SoftBurst, MaterialShape.Ghostish]

    property color offMonitorColour: Colours.palette.m3outlineVariant
    readonly property bool onOtherMonitor: {
        if (Config.bar.workspaces.perMonitor)
            return false;
        const mon = Hypr.workspaces.values.find(w => w.id === ws)?.monitor;
        return mon && mon !== monitor;
    }
    readonly property color fgColour: {
        if (onOtherMonitor)
            return offMonitorColour;
        if (focused || isOccupied || Config.bar.workspaces.occupiedBg)
            return Colours.palette.m3onSurface;
        return Colours.layer(Colours.palette.m3outlineVariant, 2);
    }

    function updateShape(): void {
        const shape = indicator.item as MaterialShape;
        if (!shape)
            return;

        if (focused)
            shape.shape = focusedShapeList[Math.floor(Math.random() * focusedShapeList.length)];
        else
            shape.shape = Qt.binding(() => isOccupied ? MaterialShape.Square : MaterialShape.Circle);
    }

    anchors.horizontalCenter: parent?.horizontalCenter
    LazyListView.preferredHeight: LazyListView.removing ? 0 : layout.implicitHeight + (hasWindows ? Tokens.padding.extraSmall : 0)
    LazyListView.visibleHeight: LazyListView.preferredHeight

    opacity: LazyListView.removing || LazyListView.adding ? 0 : 1

    onFocusedChanged: updateShape()
    Component.onCompleted: updateShape()

    Behavior on LazyListView.visibleHeight {
        Anim {}
    }

    Behavior on y {
        enabled: root.LazyListView.ready

        Anim {}
    }

    Behavior on opacity {
        Anim {
            type: Anim.DefaultEffects
        }
    }

    Component {
        id: shapeComponent

        MaterialShape {
            implicitSize: Tokens.sizes.bar.innerWidth - Tokens.padding.small

            color: root.fgColour
            scale: root.focused ? 2 / 3 : root.isOccupied ? 1 / 3 : 1 / 4

            animationEasing: Tokens.anim.expressiveDefaultSpatial
            animationDuration: Tokens.anim.durations.expressiveDefaultSpatial * Tokens.anim.durations.scale

            Behavior on color {
                CAnim {}
            }

            Behavior on scale {
                Anim {}
            }
        }
    }

    Component {
        id: textComponent

        StyledText {
            animate: true
            text: {
                if (root.focused) {
                    const label = root.activeLabel;
                    if (label)
                        return label;
                }

                if (root.focused || root.isOccupied) {
                    const label = root.occupiedLabel;
                    if (label)
                        return label;
                }

                const label = root.label;
                if (label)
                    return label;

                const ws = Hypr.workspaces.values.find(w => w.id === root.ws);
                const wsName = !ws || ws.name == root.ws ? root.ws : Hypr.trimWsName(ws.name)[0];

                const capitalisation = Config.bar.workspaces.capitalisation;
                if (capitalisation === BarWorkspaceCapitalisation.Upper)
                    return String(wsName).toUpperCase();
                else if (capitalisation === BarWorkspaceCapitalisation.Lower)
                    return String(wsName).toLowerCase();
                return wsName;
            }
            color: root.fgColour
            verticalAlignment: Qt.AlignVCenter
            font.family: Tokens.font.workspaces
        }
    }

    Component {
        id: iconComponent

        MaterialIcon {
            fill: 1
            grade: 25
            text: iconCacher.icon
            color: root.fgColour
            verticalAlignment: Qt.AlignVCenter

            WsIconCacher {
                id: iconCacher
            }
        }
    }

    Component {
        id: appIconComponent

        Item {
            id: iconBox

            implicitWidth: Tokens.sizes.bar.innerWidth - Tokens.padding.small
            implicitHeight: implicitWidth

            Item {
                id: glow

                anchors.fill: parent

                layer.enabled: root.focused
                layer.effect: MultiEffect {
                    shadowEnabled: true
                    shadowColor: Colours.palette.m3primary
                    shadowBlur: 0.55
                    shadowScale: 1.12
                    shadowOpacity: 0.95
                    shadowVerticalOffset: 0
                    shadowHorizontalOffset: 0
                }

                Image {
                    anchors.centerIn: parent
                    width: Math.round(parent.width * 0.78)
                    height: width
                    fillMode: Image.PreserveAspectFit
                    smooth: true
                    asynchronous: true
                    sourceSize.width: Math.round(width * 2)
                    sourceSize.height: Math.round(height * 2)
                    source: root.appIcon
                }
            }
        }
    }

    Component {
        id: iconLoaderComponent

        Loader {
            sourceComponent: loaderIconCacher.icon ? iconComponent : textComponent

            WsIconCacher {
                id: loaderIconCacher
            }
        }
    }

    ColumnLayout {
        id: layout

        anchors.fill: parent
        spacing: 0

        Loader {
            id: indicator

            Layout.alignment: Qt.AlignHCenter | Qt.AlignTop
            Layout.preferredHeight: Tokens.sizes.bar.innerWidth - Tokens.padding.small
            sourceComponent: {
                if (root.displayType === BarWorkspaceDisplay.Text)
                    return textComponent;
                if (root.isOccupied && root.appIcon)
                    return appIconComponent;
                if (root.displayType === BarWorkspaceDisplay.Icons)
                    return iconLoaderComponent;
                return shapeComponent;
            }

            onItemChanged: root.updateShape()
        }

    }

    component WsIconCacher: QtObject {
        id: cacher

        property string name
        readonly property string icon: Icons.matchIconRuleList(Hypr.trimWsName(name), root.iconRules)
        readonly property HyprlandWorkspace wsObj: Hypr.workspaces.values.find(w => w.id === root.ws) ?? null

        readonly property Connections conn: Connections {
            function onNameChanged(): void {
                cacher.updateName();
            }

            target: cacher.wsObj
        }

        function updateName(): void {
            if (wsObj)
                name = wsObj.name;
        }

        onWsObjChanged: updateName()
        Component.onCompleted: updateName()
    }
}
