pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Caelestia
import Caelestia.Config
import qs.components
import qs.modules.bar.popouts as BarPopouts
import qs.modules.utilities as Utilities
import qs.modules.utilities.cards

Item {
    id: root

    required property ScreenState screenState
    required property BarPopouts.Wrapper popouts
    property real keepAwakeHeight: 0
    property real contentBottom: 0

    readonly property PersistentProperties props: PersistentProperties {
        property bool recordingListExpanded: false
        property string recordingConfirmDelete
        property string recordingMode

        reloadableId: "overviewUtilities"
    }

    implicitWidth: Tokens.sizes.utilities.width
    implicitHeight: column.implicitHeight

    Column {
        id: column

        spacing: Tokens.spacing.large

        KeepAwakeCard {
            width: root.implicitWidth
            cardHeight: root.keepAwakeHeight
        }

        Toggles {
            width: root.implicitWidth
            minHeight: Math.max(0, root.contentBottom - root.keepAwakeHeight - Tokens.spacing.large)
            screenState: root.screenState
            popouts: root.popouts
        }
    }
}
