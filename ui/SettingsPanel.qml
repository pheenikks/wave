import QtQuick
import "Util.js" as Util

// Flyout with the theme chooser and the on/off switches.
Rectangle {
    id: panel

    property var ui
    property var themes: []            // theme names to cycle through
    signal edited(string key, var value)

    readonly property var t: ui.t
    readonly property var cfg: ui.cfg
    readonly property string fg: t.colors.dockText

    // Each switch: where it lives in the config and what flipping it writes.
    readonly property var rows: allRows.filter(function (r) { return !(r.linuxOnly && ui.platform === "windows"); })
    readonly property var allRows: [
        { label: "Side panel labels", on: cfg.features.dockLabels, feature: "dockLabels" },
        { label: "Big title", on: cfg.features.hero, feature: "hero" },
        { label: "Background scene", on: cfg.features.scene, feature: "scene" },
        { label: "Background motion", on: cfg.features.motion, feature: "motion" },
        { label: "Key hints", on: cfg.features.hints, feature: "hints" },
        { label: "Tape wear", on: cfg.features.wear, feature: "wear" },
        { label: "Film grain", on: cfg.features.grain, feature: "grain" },
        { label: "Opening animation", on: cfg.animation.intro, key: "animation", value: Util.merge(cfg.animation, { intro: !cfg.animation.intro }) },
        { label: "Wrap around the shelf", on: cfg.wrap, key: "wrap", value: !cfg.wrap },
        { label: "Close after launching", on: cfg.closeOnLaunch, key: "closeOnLaunch", value: !cfg.closeOnLaunch },
        { label: "Dedicated GPU for every game", on: cfg.primeAll, key: "primeAll", value: !cfg.primeAll, linuxOnly: true },
        { label: "GameMode for every game", on: cfg.gamemode, key: "gamemode", value: !cfg.gamemode, linuxOnly: true },
        { label: "Quiet Steam launch", on: cfg.steamQuiet, key: "steamQuiet", value: !cfg.steamQuiet, linuxOnly: true },
        { label: "Keep loaded when closed", on: cfg.preload, key: "preload", value: !cfg.preload },
        { label: "Quit Wave while playing", on: cfg.quitOnLaunch, key: "quitOnLaunch", value: !cfg.quitOnLaunch }
    ]

    function flip(row) {
        if (row.feature) {
            var patch = {};
            patch[row.feature] = !row.on;
            edited("features", Util.merge(cfg.features, patch));
        } else {
            edited(row.key, row.value);
        }
    }
    function stepTheme(d) {
        var i = themes.indexOf(cfg.theme);
        edited("theme", themes[(Math.max(0, i) + d + themes.length) % themes.length]);
    }

    width: ui.px(308)
    height: col.implicitHeight + ui.px(44)
    color: "transparent"   // sits inside the side panel's drawer

    MouseArea { anchors.fill: parent; acceptedButtons: Qt.AllButtons }

    Column {
        id: col
        x: ui.px(22); y: ui.px(22)
        width: parent.width - ui.px(44)
        spacing: ui.px(4)

        Text {
            text: "Settings"
            color: panel.fg
            font { family: t.fonts.label; pixelSize: ui.px(16); weight: Font.DemiBold }
            bottomPadding: ui.px(8)
        }

        // theme chooser
        Rectangle {
            width: parent.width; height: ui.px(40); radius: height / 2
            color: "#19191c"
            Repeater {
                model: 2
                Item {
                    required property int index
                    x: index ? parent.width - width : 0
                    width: ui.px(40); height: parent.height
                    Icon {
                        anchors.centerIn: parent
                        width: ui.px(18); height: width
                        name: index ? "right" : "left"
                        color: panel.fg
                        opacity: stepArea.containsMouse ? 1 : 0.6
                    }
                    MouseArea { id: stepArea; anchors.fill: parent; hoverEnabled: true; onClicked: panel.stepTheme(index ? 1 : -1) }
                }
            }
            Column {
                anchors.centerIn: parent
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "THEME"
                    color: Util.alpha(panel.fg, 0.55)
                    font { family: t.fonts.label; pixelSize: ui.px(8); weight: Font.Medium; letterSpacing: 1.2 }
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: t.name || cfg.theme
                    color: panel.fg
                    font { family: t.fonts.label; pixelSize: ui.px(13); weight: Font.DemiBold }
                }
            }
        }
        Item { width: 1; height: ui.px(6) }

        Repeater {
            model: panel.rows
            Item {
                id: row
                required property var modelData
                width: col.width; height: ui.px(30)
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - ui.px(52)
                    elide: Text.ElideRight
                    text: row.modelData.label
                    color: Util.alpha(panel.fg, row.modelData.on ? 1 : 0.7)
                    font { family: t.fonts.label; pixelSize: ui.px(13); weight: Font.Medium }
                }
                Rectangle { // switch
                    anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                    width: ui.px(40); height: ui.px(22); radius: height / 2
                    color: row.modelData.on ? "#30d158" : "#3a3a3d"
                    Behavior on color { ColorAnimation { duration: 140 } }
                    Rectangle {
                        y: ui.px(3); x: row.modelData.on ? parent.width - width - ui.px(3) : ui.px(3)
                        Behavior on x { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
                        width: ui.px(16); height: width; radius: width / 2
                        color: "#ffffff"
                    }
                }
                MouseArea { anchors.fill: parent; onClicked: panel.flip(row.modelData) }
            }
        }
    }
}
