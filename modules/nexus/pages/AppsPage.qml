pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import Caelestia
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.containers
import qs.services
import qs.utils
import qs.modules.nexus.common

PageBase {
    id: root

    title: Tr.tr("Apps")

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        // Default applications
        SectionHeader {
            first: true
            text: Tr.tr("Default applications")
        }

        DefaultRow {
            first: true
            icon: "terminal"
            label: Tr.trCtx("Terminal", "default app category")
            status: GlobalConfig.general.apps.terminal.join(" ")
            onSelected: app => GlobalConfig.general.apps.terminal = app.command
        }

        DefaultRow {
            icon: "volume_up"
            label: Tr.trCtx("Audio", "default app category")
            status: GlobalConfig.general.apps.audio.join(" ")
            onSelected: app => GlobalConfig.general.apps.audio = app.command
        }

        DefaultRow {
            icon: "play_circle"
            label: Tr.trCtx("Media playback", "default app category")
            status: GlobalConfig.general.apps.playback.join(" ")
            onSelected: app => GlobalConfig.general.apps.playback = app.command
        }

        DefaultRow {
            last: true
            icon: "folder"
            label: Tr.trCtx("File manager", "default app category")
            status: GlobalConfig.general.apps.explorer.join(" ")
            onSelected: app => GlobalConfig.general.apps.explorer = app.command
        }

        // System handlers (xdg-mime defaults)
        SectionHeader {
            visible: MimeDefaults.entries.length > 0
            text: Tr.tr("System handlers")
        }

        HandlerRow {
            type: "x-scheme-handler/https"
            icon: "public"
            label: Tr.tr("Web browser")
        }

        HandlerRow {
            type: "x-scheme-handler/mailto"
            icon: "mail"
            label: Tr.tr("Email")
        }

        HandlerRow {
            type: "x-scheme-handler/tg"
            icon: "chat"
            label: Tr.tr("Telegram links")
        }

        HandlerRow {
            type: "x-scheme-handler/tonsite"
            icon: "chat_bubble"
            label: Tr.tr("Telegram site links")
        }

        HandlerRow {
            type: "x-scheme-handler/magnet"
            icon: "download"
            label: Tr.tr("Torrents")
        }

        HandlerRow {
            type: "inode/directory"
            icon: "folder"
            label: Tr.tr("File manager")
        }

        HandlerRow {
            type: "text/plain"
            icon: "edit_document"
            label: Tr.tr("Text editor")
        }

        HandlerRow {
            type: "video/mp4"
            icon: "movie"
            label: Tr.tr("Video")
        }

        HandlerRow {
            type: "audio/mpeg"
            icon: "music_note"
            label: Tr.tr("Music")
        }

        HandlerRow {
            type: "image/png"
            icon: "image"
            label: Tr.tr("Images")
        }

        HandlerRow {
            type: "application/pdf"
            icon: "picture_as_pdf"
            label: Tr.tr("PDF")
        }

        // Library
        SectionHeader {
            text: Tr.trCtx("Library", "app library")
        }

        NavRow {
            first: true
            last: true
            icon: "apps"
            text: Tr.tr("All apps")
            subtext: Tr.tr("Browse installed apps, set favourites and hidden")
            onClicked: root.nState.openSubPage(1)
        }
    }

    component HandlerRow: PopupRow {
        id: row

        required property string type

        readonly property var registered: MimeDefaults.registered(row.type)
        readonly property int popupHeight: root.flickable.height - y + root.flickable.contentY - Tokens.padding.large - Tokens.padding.extraExtraLarge

        visible: row.registered.length > 0
        status: MimeDefaults.applicationName(MimeDefaults.current(row.type)) || Tr.tr("Not set")

        // Keep the (closed) trigger button inside the page so it fades and clips together with the
        // row; only the open popup is reparented to the window so it can overflow the list.
        keepPopupAsChild: !row.popup.open || root.nState.animatingContainer || root.opacity < 1
        popup.topMovement: Math.max(Tokens.sizes.nexus.minPopupHeight - popupHeight, Tokens.padding.large)

        Loader {
            anchors.centerIn: parent
            active: row.popup.animDriver > 0

            sourceComponent: VerticalFadeListView {
                id: list

                implicitWidth: Tokens.sizes.nexus.popupWidth
                implicitHeight: CUtils.clamp(row.popupHeight, Tokens.sizes.nexus.minPopupHeight, Tokens.sizes.nexus.maxPopupHeight)

                model: row.registered

                delegate: StateLayer {
                    id: handlerItem

                    required property var modelData

                    anchors.fill: undefined
                    anchors.left: list.contentItem.left
                    anchors.right: list.contentItem.right
                    implicitHeight: handlerLayout.implicitHeight + handlerLayout.anchors.margins * 2
                    radius: Tokens.rounding.small

                    onClicked: {
                        row.popup.open = false;
                        MimeDefaults.setDefault(row.type, handlerItem.modelData);
                    }

                    RowLayout {
                        id: handlerLayout

                        anchors.fill: parent
                        anchors.margins: Tokens.padding.medium
                        spacing: Tokens.spacing.medium

                        IconImage {
                            asynchronous: true
                            implicitSize: Math.round(Tokens.font.icon.large.pointSize * 1.8)
                            source: MimeDefaults.applicationIcon(handlerItem.modelData)
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: MimeDefaults.applicationName(handlerItem.modelData)
                            font: Tokens.font.body.medium
                            elide: Text.ElideRight
                        }

                        MaterialIcon {
                            visible: handlerItem.modelData === MimeDefaults.current(row.type)
                            text: "check"
                            color: Colours.palette.m3primary
                            fontStyle: Tokens.font.icon.small
                        }
                    }
                }
            }
        }
    }

    component DefaultRow: PopupRow {
        id: row

        readonly property int popupHeight: root.flickable.height - y + root.flickable.contentY - Tokens.padding.large - Tokens.padding.extraExtraLarge

        signal selected(app: DesktopEntry)

        // Keep the (closed) trigger button inside the page so it fades and clips together with the
        // row; only the open popup is reparented to the window so it can overflow the list.
        keepPopupAsChild: !row.popup.open || root.nState.animatingContainer || root.opacity < 1
        popup.topMovement: Math.max(Tokens.sizes.nexus.minPopupHeight - popupHeight, Tokens.padding.large)

        Loader {
            anchors.centerIn: parent
            active: row.popup.animDriver > 0

            sourceComponent: VerticalFadeListView {
                id: list

                implicitWidth: Tokens.sizes.nexus.popupWidth
                implicitHeight: CUtils.clamp(row.popupHeight, Tokens.sizes.nexus.minPopupHeight, Tokens.sizes.nexus.maxPopupHeight)

                model: {
                    const apps = [...DesktopEntries.applications.values];
                    const favourited = new Set(apps.filter(a => Strings.testRegexList(GlobalConfig.launcher.favouriteApps, a.id)));
                    return apps.sort((a, b) => (favourited.has(b) - favourited.has(a)) || a.name.localeCompare(b.name));
                }

                delegate: StateLayer {
                    id: appItem

                    required property DesktopEntry modelData
                    required property int index

                    anchors.fill: undefined
                    anchors.left: list.contentItem.left
                    anchors.right: list.contentItem.right
                    implicitHeight: itemLayout.implicitHeight + itemLayout.anchors.margins * 2
                    radius: Tokens.rounding.small

                    onClicked: {
                        row.popup.open = false;
                        row.selected(modelData);
                    }

                    RowLayout {
                        id: itemLayout

                        anchors.fill: parent
                        anchors.margins: Tokens.padding.medium
                        spacing: Tokens.spacing.medium

                        IconImage {
                            asynchronous: true
                            implicitSize: Math.round(Tokens.font.icon.large.pointSize * 1.8)
                            source: Quickshell.iconPath(appItem.modelData.icon, "image-missing")
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0

                            StyledText {
                                Layout.fillWidth: true
                                text: appItem.modelData.name
                                font: Tokens.font.body.small
                                elide: Text.ElideRight
                            }

                            StyledText {
                                Layout.fillWidth: true
                                visible: text
                                text: (appItem.modelData.comment || appItem.modelData.genericName) ?? ""
                                color: Colours.palette.m3outline
                                font: Tokens.font.label.small
                                elide: Text.ElideRight
                            }
                        }

                        MaterialIcon {
                            visible: Strings.testRegexList(GlobalConfig.launcher.favouriteApps, appItem.modelData.id)
                            text: "favorite"
                            fill: 1
                            color: Colours.palette.m3primary
                            fontStyle: Tokens.font.icon.small
                        }
                    }
                }
            }
        }
    }
}
