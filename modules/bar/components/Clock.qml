pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.services

StyledRect {
    id: root

    readonly property color colour: Colours.palette.m3tertiary
    readonly property int padding: Config.bar.clock.background ? Tokens.padding.medium : Tokens.padding.extraSmall
    readonly property var font: Tokens.font.body.builders.small.scale(1.1)

    function fontFor(text: string, metricWidth: int): font {
        // We don't count seconds for the max width because it changes too often
        const scale = text === "11" ? 1.15 : Math.min(1.05, Math.max(hourMetrics.width, minMetrics.width) / metricWidth);
        return root.font.width(scale * 100).letterSpacing(scale).build();
    }

    readonly property bool vertical: BarPos.vertical

    implicitWidth: root.vertical ? Tokens.sizes.bar.innerWidth : horizontal.implicitWidth + root.padding * 2
    implicitHeight: root.vertical ? layout.implicitHeight + root.padding * 2 : Tokens.sizes.bar.innerWidth

    color: Qt.alpha(Colours.tPalette.m3surfaceContainer, Config.bar.clock.background ? Colours.tPalette.m3surfaceContainer.a : 0)
    radius: Tokens.rounding.full

    ColumnLayout {
        id: layout

        visible: root.vertical
        anchors.centerIn: parent
        spacing: Tokens.spacing.extraSmall

        Loader {
            Layout.alignment: Qt.AlignHCenter
            asynchronous: true
            active: Config.bar.clock.showIcon
            visible: active

            sourceComponent: MaterialIcon {
                text: "calendar_month"
                color: root.colour
            }
        }

        Loader {
            Layout.alignment: Qt.AlignHCenter
            asynchronous: true
            active: Config.bar.clock.showDate
            visible: active

            sourceComponent: ColumnLayout {
                spacing: layout.spacing - 4

                StyledText {
                    Layout.alignment: Qt.AlignHCenter
                    text: Time.format("ddd")
                    font: Tokens.font.body.builders.small.scale(0.9).build()
                    color: root.colour
                }

                StyledText {
                    Layout.alignment: Qt.AlignHCenter
                    text: Time.format("d")
                    font: root.font.scale(1.1).build()
                    color: root.colour
                }

                StyledRect {
                    Layout.fillWidth: true
                    Layout.leftMargin: -Tokens.padding.extraSmall
                    Layout.rightMargin: -Tokens.padding.extraSmall
                    Layout.topMargin: 4
                    Layout.bottomMargin: Tokens.padding.extraSmall / 2
                    implicitHeight: 1
                    color: Colours.palette.m3outlineVariant
                }
            }
        }

        StyledText {
            Layout.alignment: Qt.AlignHCenter
            text: Time.hourStr
            font: root.fontFor(text, hourMetrics.width)
            color: root.colour

            TextMetrics {
                id: hourMetrics

                font: root.font.build()
                text: Time.hourStr
            }
        }

        StyledText {
            Layout.topMargin: -parent.spacing - 4
            Layout.alignment: Qt.AlignHCenter
            text: Time.minuteStr
            font: root.fontFor(text, minMetrics.width)
            color: root.colour

            TextMetrics {
                id: minMetrics

                font: root.font.build()
                text: Time.minuteStr
            }
        }

        Loader {
            Layout.topMargin: -parent.spacing - 4
            Layout.alignment: Qt.AlignHCenter
            asynchronous: true
            active: Config.bar.clock.showSeconds
            visible: active

            sourceComponent: StyledText {
                text: Time.format("ss")
                font: root.fontFor(text, secMetrics.width)
                color: root.colour

                TextMetrics {
                    id: secMetrics

                    font: root.font.build()
                    text: Time.format("ss")
                }
            }
        }

        Loader {
            Layout.topMargin: -parent.spacing - 4
            Layout.alignment: Qt.AlignHCenter
            asynchronous: true
            active: Units.twelveHourClock
            visible: active

            sourceComponent: StyledText {
                text: Time.amPmStr.toLowerCase()
                font: Tokens.font.body.builders.small.scale(0.9).build()
                color: root.colour
            }
        }
    }

    RowLayout {
        id: horizontal

        visible: !root.vertical
        anchors.centerIn: parent
        spacing: Tokens.spacing.small

        MaterialIcon {
            Layout.alignment: Qt.AlignVCenter
            visible: Config.bar.clock.showIcon
            text: "calendar_month"
            color: root.colour
        }

        StyledText {
            Layout.alignment: Qt.AlignVCenter
            visible: Config.bar.clock.showDate
            text: Time.format("ddd d")
            font: Tokens.font.body.builders.small.scale(0.95).build()
            color: root.colour
        }

        StyledText {
            Layout.alignment: Qt.AlignVCenter
            text: `${Time.hourStr}:${Time.minuteStr}`
            font: root.font.build()
            color: root.colour
        }

        StyledText {
            Layout.alignment: Qt.AlignVCenter
            visible: Config.bar.clock.showSeconds
            text: Time.format("ss")
            font: root.font.build()
            color: root.colour
        }

        StyledText {
            Layout.alignment: Qt.AlignVCenter
            visible: Units.twelveHourClock
            text: Time.amPmStr.toLowerCase()
            font: Tokens.font.body.builders.small.scale(0.9).build()
            color: root.colour
        }
    }

    // Local patch: clicking the clock toggles 24h/12h
    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor

        onClicked: GlobalConfig.services.clockFormat = Units.twelveHourClock ? ClockFormat.TwentyFourHour : ClockFormat.TwelveHour
    }
}
