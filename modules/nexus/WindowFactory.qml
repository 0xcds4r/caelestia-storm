pragma Singleton

import QtQuick
import Quickshell
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.services
import qs.modules.nexus

Singleton {
    id: root

    // The window (and its pages) is kept alive between openings: every re-creation allocated a new
    // layer surface plus a fresh page (the wallpaper grid alone cost ~100 MB per open), so the
    // shell grew by that much on every Nexus visit.
    property var instance: null

    function create(parent: Item, props: var): void {
        if (root.instance) {
            root.instance.visible = true;
            return;
        }

        root.instance = nexusComp.createObject(parent ?? dummy, props ?? {});
    }

    QtObject {
        id: dummy
    }

    Component {
        id: nexusComp

        FloatingWindow {
            id: win

            color: Colours.tPalette.m3surface
            surfaceFormat.opaque: false

            // hidden, not destroyed — see `instance` above
            visible: false

            implicitWidth: nexus.implicitWidth
            implicitHeight: nexus.implicitHeight

            minimumSize.width: contentItem.Tokens.sizes.nexus.minWidth
            minimumSize.height: contentItem.Tokens.sizes.nexus.minHeight

            contentItem.Config.screen: screen.name
            contentItem.Tokens.screen: screen.name

            title: Tr.tr("Nexus — %1").arg(PageRegistry.pages[nexus.nState.currentPageIdx].label)

            Nexus {
                id: nexus

                anchors.fill: parent
                nState.screen: win.screen
                nState.isWindow: true
                onClose: win.visible = false
            }

            Behavior on color {
                CAnim {}
            }
        }
    }
}
