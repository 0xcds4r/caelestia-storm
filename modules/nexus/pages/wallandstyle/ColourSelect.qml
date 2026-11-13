pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.controls
import qs.services
import qs.modules.nexus.common

PageBase {
    id: root

    title: Tr.tr("Colours")
    isSubPage: true

    // Schemes with more than one flavour; the rest only have a single "default" one.
    readonly property var schemeFlavours: ({
            "catppuccin": ["frappe", "latte", "macchiato", "mocha"],
            "darkgreen": ["hard", "medium"],
            "everforest": ["hard", "medium", "soft"],
            "gruvbox": ["hard", "medium", "soft"],
            "rosepine": ["dawn", "main", "moon"]
        })

    readonly property var flavours: root.schemeFlavours[Colours.scheme] ?? []

    readonly property var schemeList: [
        {
            value: "dynamic",
            label: Tr.tr("Dynamic")
        },
        {
            value: "caelestia",
            label: "Caelestia"
        },
        {
            value: "catppuccin",
            label: "Catppuccin"
        },
        {
            value: "darkgreen",
            label: Tr.tr("Dark Green")
        },
        {
            value: "dracula",
            label: "Dracula"
        },
        {
            value: "everblush",
            label: "Everblush"
        },
        {
            value: "everforest",
            label: "Everforest"
        },
        {
            value: "gruvbox",
            label: "Gruvbox"
        },
        {
            value: "nord",
            label: "Nord"
        },
        {
            value: "oldworld",
            label: Tr.tr("Old World")
        },
        {
            value: "onedark",
            label: Tr.tr("One Dark")
        },
        {
            value: "rosepine",
            label: "Rosé Pine"
        },
        {
            value: "shadotheme",
            label: Tr.tr("Shado Theme")
        },
        {
            value: "solarized",
            label: "Solarized"
        },
        {
            value: "tokyonight",
            label: Tr.tr("Tokyo Night")
        }
    ]
    readonly property var variants: [variantTonalspot, variantVibrant, variantExpressive, variantFidelity, variantFruitsalad, variantMonochrome, variantNeutral, variantRainbow, variantContent]

    // `-m` is only forced where the scheme itself cannot imply it: flavours like catppuccin's
    // `latte` set the mode themselves, and forcing one produced inconsistent light/dark palettes.
    function apply(name: string, flavour: string, variant: string, forceMode: bool): void {
        const args = ["caelestia", "scheme", "set", "--notify", "-n", name];

        const available = root.schemeFlavours[name] ?? [];
        if (flavour && available.indexOf(flavour) !== -1)
            args.push("-f", flavour);
        if (variant)
            args.push("-v", variant);
        if (forceMode)
            args.push("-m", Colours.light ? "light" : "dark");

        if (UiPrefs.appliedPluginScheme) {
            UiPrefs.appliedPluginScheme = "";
            UiPrefs.save();
        }
        Quickshell.execDetached(args);
    }

    readonly property bool schemeHasFlavours: (root.schemeFlavours[Colours.scheme]?.length ?? 0) > 1

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        // Scheme
        SectionHeader {
            first: true
            text: Tr.tr("Scheme")
        }

        ConnectedRect {
            Layout.fillWidth: true
            first: true
            last: root.flavours.length < 2

            implicitHeight: schemeColumn.implicitHeight + Tokens.padding.medium * 2

            ColumnLayout {
                id: schemeColumn

                anchors.fill: parent
                anchors.margins: Tokens.padding.medium
                anchors.leftMargin: Tokens.padding.largeIncreased
                anchors.rightMargin: Tokens.padding.largeIncreased
                spacing: Tokens.spacing.small

                StyledText {
                    Layout.fillWidth: true
                    text: Tr.tr("Colour scheme")
                    font: Tokens.font.body.small
                }

                Flow {
                    Layout.fillWidth: true
                    spacing: Tokens.spacing.small

                    Repeater {
                        model: root.schemeList

                        Chip {
                            required property var modelData

                            text: modelData.label
                            selected: Colours.scheme === modelData.value
                            onClicked: root.apply(modelData.value, Colours.flavour, Colours.variant, !(root.schemeFlavours[modelData.value]?.length > 1))
                        }
                    }
                }
            }
        }

        // Flavour
        SectionHeader {
            visible: root.flavours.length > 1
            text: Tr.tr("Flavour")
        }

        ConnectedRect {
            Layout.fillWidth: true
            visible: root.flavours.length > 1
            first: true
            last: true

            implicitHeight: flavourRow.implicitHeight + Tokens.padding.medium * 2

            RowLayout {
                id: flavourRow

                anchors.fill: parent
                anchors.margins: Tokens.padding.medium
                anchors.leftMargin: Tokens.padding.largeIncreased
                anchors.rightMargin: Tokens.padding.largeIncreased
                spacing: Tokens.spacing.small

                StyledText {
                    Layout.fillWidth: true
                    text: Tr.tr("Flavour")
                    font: Tokens.font.body.small
                }

                Repeater {
                    model: root.flavours

                    Chip {
                        required property string modelData

                        text: modelData
                        selected: Colours.flavour === modelData
                        onClicked: root.apply(Colours.scheme, modelData, Colours.variant, false)
                    }
                }
            }
        }

        // Plugin schemes
        SectionHeader {
            visible: Plugins.schemes.length > 0
            text: Tr.tr("Plugin schemes")
        }

        ConnectedRect {
            Layout.fillWidth: true
            visible: Plugins.schemes.length > 0
            first: true
            last: true

            implicitHeight: pluginColumn.implicitHeight + Tokens.padding.medium * 2

            ColumnLayout {
                id: pluginColumn

                anchors.fill: parent
                anchors.margins: Tokens.padding.medium
                anchors.leftMargin: Tokens.padding.largeIncreased
                anchors.rightMargin: Tokens.padding.largeIncreased
                spacing: Tokens.spacing.small

                StyledText {
                    Layout.fillWidth: true
                    text: Tr.tr("Provided by installed plugins")
                    font: Tokens.font.body.small
                }

                Flow {
                    Layout.fillWidth: true
                    spacing: Tokens.spacing.small

                    Repeater {
                        model: Plugins.schemes

                        Chip {
                            required property var modelData

                            text: `${modelData.name} · ${modelData.pluginName}`
                            selected: UiPrefs.appliedPluginScheme === modelData.key
                            onClicked: Plugins.applyScheme(modelData)
                        }
                    }
                }
            }
        }

        // Variant
        SectionHeader {
            text: Tr.tr("Palette")
        }

        SelectRow {
            first: true
            last: true
            label: Tr.tr("Variant")
            subtext: Tr.tr("How the accents are derived from the scheme")
            active: root.variants.find(item => item.value === Colours.variant) ?? variantTonalspot

            onSelected: item => root.apply(Colours.scheme, Colours.flavour, item.value, true)

            menuItems: root.variants

            MenuItem {
                id: variantTonalspot

                text: Tr.tr("Tonal spot")
                value: "tonalspot"
            }

            MenuItem {
                id: variantVibrant

                text: Tr.tr("Vibrant")
                value: "vibrant"
            }

            MenuItem {
                id: variantExpressive

                text: Tr.tr("Expressive")
                value: "expressive"
            }

            MenuItem {
                id: variantFidelity

                text: Tr.tr("Fidelity")
                value: "fidelity"
            }

            MenuItem {
                id: variantFruitsalad

                text: Tr.tr("Fruit salad")
                value: "fruitsalad"
            }

            MenuItem {
                id: variantMonochrome

                text: Tr.tr("Monochrome")
                value: "monochrome"
            }

            MenuItem {
                id: variantNeutral

                text: Tr.tr("Neutral")
                value: "neutral"
            }

            MenuItem {
                id: variantRainbow

                text: Tr.tr("Rainbow")
                value: "rainbow"
            }

            MenuItem {
                id: variantContent

                text: Tr.tr("Content")
                value: "content"
            }
        }

        StyledRect {
            id: randomButton

            Layout.topMargin: Tokens.spacing.medium
            Layout.fillWidth: true
            implicitHeight: Math.max(randomIcon.implicitHeight, randomText.implicitHeight) + Tokens.padding.medium * 2
            radius: implicitHeight / 2 * Math.min(1, Tokens.rounding.scale)
            color: Colours.palette.m3secondaryContainer

            StateLayer {
                anchors.fill: parent
                radius: parent.radius
                onClicked: Quickshell.execDetached(["caelestia", "scheme", "set", "--notify", "--random"])
            }

            Row {
                anchors.centerIn: parent
                spacing: Tokens.spacing.small

                MaterialIcon {
                    id: randomIcon

                    anchors.verticalCenter: parent.verticalCenter
                    text: "casino"
                    color: Colours.palette.m3onSecondaryContainer
                    fill: 1
                }

                StyledText {
                    id: randomText

                    anchors.verticalCenter: parent.verticalCenter
                    text: Tr.tr("Random scheme")
                    color: Colours.palette.m3onSecondaryContainer
                    font: Tokens.font.body.small
                }
            }

            Behavior on color {
                CAnim {}
            }
        }
    }

    component Chip: StyledRect {
        id: chip

        required property string text
        property bool selected

        signal clicked

        implicitWidth: chipText.implicitWidth + Tokens.padding.largeIncreased
        implicitHeight: chipText.implicitHeight + Tokens.padding.small * 2
        radius: Tokens.rounding.full
        color: chip.selected ? Colours.palette.m3secondaryContainer : Colours.palette.m3surfaceContainerHigh

        StyledText {
            id: chipText

            anchors.centerIn: parent
            text: chip.text
            color: chip.selected ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onSurfaceVariant
            font: Tokens.font.label.medium
        }

        StateLayer {
            anchors.fill: parent
            radius: parent.radius
            onClicked: chip.clicked()
        }

        Behavior on color {
            CAnim {}
        }
    }
}
