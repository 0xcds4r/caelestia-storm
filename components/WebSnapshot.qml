pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Caelestia.Config
import Caelestia.I18n
import qs.services

// Render-only web view: the page is captured with headless Chromium and refreshed periodically.
// QtWebEngine cannot be embedded in this Quickshell build (Chromium aborts without argv), so plugins
// get real rendered pages without live interaction.
Item {
    id: root

    required property string url
    property int captureWidth: 900
    property int captureHeight: 500
    property int refreshInterval: 60000
    property int fillMode: Image.PreserveAspectCrop

    property string imagePath: ""
    property int revision: 0

    implicitWidth: root.captureWidth
    implicitHeight: root.captureHeight

    function refresh(): void {
        if (snapshot.running || !root.url)
            return;

        snapshot.running = true;
    }

    Image {
        anchors.fill: parent
        fillMode: root.fillMode
        asynchronous: true
        cache: false
        source: root.imagePath ? `file://${root.imagePath}?${root.revision}` : ""
    }

    StyledText {
        anchors.centerIn: parent
        visible: !root.imagePath
        text: Tr.tr("Loading…")
        color: Colours.palette.m3onSurfaceVariant
        font: Tokens.font.label.small
    }

    Process {
        id: snapshot

        command: ["sh", Quickshell.shellPath("scripts/webview-snapshot.sh"), root.url, root.captureWidth, root.captureHeight]

        stdout: StdioCollector {
            onStreamFinished: {
                const path = text.trim();
                if (path) {
                    root.imagePath = path;
                    root.revision++;
                }
            }
        }
    }

    Timer {
        interval: root.refreshInterval
        running: root.visible && root.url !== ""
        repeat: true

        onTriggered: root.refresh()
    }

    onUrlChanged: {
        root.imagePath = "";
        root.refresh();
    }

    Component.onCompleted: root.refresh()
}
