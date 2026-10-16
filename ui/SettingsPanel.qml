import QtQuick
import "Util.js" as Util

// Flyout with the theme chooser and the on/off switches.
Rectangle {
    id: panel

    property var ui
    property var themes: []            // theme names to cycle through
    signal edited(string key, var value)
    signal wallpaperRequested()

    readonly property var t: ui.t
    readonly property var cfg: ui.cfg
    readonly property string fg: t.colors.dockText

    // Each switch: where it lives in the config and what flipping it writes.
    readonly property var rows: allRows.filter(function (r) {
        return !(r.linuxOnly && ui.platform === "windows") && !(r.needsWallpaper && !cfg.wallpaper);
    })
    readonly property var allRows: [
        { label: "Darken wallpaper", on: cfg.wallpaperDim > 0.25, key: "wallpaperDim", value: cfg.wallpaperDim > 0.25 ? 0.12 : 0.45, needsWallpaper: true },
        { label: "Auto-hide side panel", on: cfg.features.dockAutoHide, feature: "dockAutoHide" },
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
        { label: "Start Steam minimised", on: cfg.steamQuiet, key: "steamQuiet", value: !cfg.steamQuiet, linuxOnly: true },
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

    Flickable { // scrolls when the list is taller than the side panel
        anchors.fill: parent
        contentHeight: col.implicitHeight + ui.px(44)
        clip: true
        boundsBehavior: Flickable.StopAtBounds
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
        // wallpaper
        Item {
            width: parent.width; height: ui.px(46)
            Column {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - wpButtons.width - ui.px(10)
                Text {
                    text: "Wallpaper"
                    color: panel.fg
                    font { family: t.fonts.label; pixelSize: ui.px(13); weight: Font.Medium }
                }
                Text {
                    width: parent.width
                    elide: Text.ElideMiddle
                    text: cfg.wallpaper ? String(cfg.wallpaper).split("/").pop() : "None"
                    color: Util.alpha(panel.fg, 0.55)
                    font { family: t.fonts.label; pixelSize: ui.px(11) }
                }
            }
            Row {
                id: wpButtons
                anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                spacing: ui.px(6)
                Rectangle {
                    width: chooseLabel.implicitWidth + ui.px(22); height: ui.px(28); radius: height / 2
                    color: chooseArea.containsMouse ? "#2a2a2d" : "#19191c"
                    Text {
                        id: chooseLabel
                        anchors.centerIn: parent
                        text: cfg.wallpaper ? "Change" : "Choose"
                        color: panel.fg
                        font { family: t.fonts.label; pixelSize: ui.px(12); weight: Font.Medium }
                    }
                    MouseArea { id: chooseArea; anchors.fill: parent; hoverEnabled: true; onClicked: panel.wallpaperRequested() }
                }
                Rectangle {
                    visible: !!cfg.wallpaper
                    width: ui.px(28); height: width; radius: width / 2
                    color: clearArea.containsMouse ? "#2a2a2d" : "#19191c"
                    Text {
                        anchors.centerIn: parent
                        text: "\u00d7"
                        color: panel.fg
                        font { family: t.fonts.label; pixelSize: ui.px(16) }
                    }
                    MouseArea { id: clearArea; anchors.fill: parent; hoverEnabled: true; onClicked: panel.edited("wallpaper", "") }
                }
            }
        }
        Item { width: 1; height: ui.px(2) }

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
}
