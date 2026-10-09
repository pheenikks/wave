import QtQuick
import "Util.js" as Util

// Flyout for the colour scheme: one accent colour and one background, from
// which Wave derives everything else (see Util.paletteColors).
Rectangle {
    id: picker

    property var ui
    property string primary: "#2f80d8"
    property string base: "#041a40"
    property bool custom: false          // a palette is set in the config
    signal picked(string primary, string base)
    signal reset()

    readonly property var t: ui.t
    readonly property string fg: t.colors.dockText
    readonly property var accents: ["#2f80d8", "#19b8d6", "#00c2a8", "#30d158", "#f5b301", "#ff7a3d",
                                    "#e9452f", "#ff3d9a", "#a855f7", "#6203fc", "#8d8a84", "#e8e6e1"]
    readonly property var grounds: ["#000000", Util.mix(primary, "#000000", 0.84), "#041a40", "#1b1b1c", "#f0ebdf"]

    width: ui.px(308)
    height: col.implicitHeight + ui.px(44)
    color: "transparent"   // sits inside the side panel's drawer

    MouseArea { anchors.fill: parent; acceptedButtons: Qt.AllButtons }

    function same(a, b) { return Util.hex(Util.rgb(a)) === Util.hex(Util.rgb(b)); }

    Column {
        id: col
        x: ui.px(22); y: ui.px(22)
        width: parent.width - ui.px(44)
        spacing: ui.px(14)

        Text {
            text: "Colour scheme"
            color: picker.fg
            font { family: t.fonts.label; pixelSize: ui.px(16); weight: Font.DemiBold }
        }

        Text {
            text: "ACCENT"
            color: Util.alpha(picker.fg, 0.6)
            font { family: t.fonts.label; pixelSize: ui.px(10); weight: Font.Medium; letterSpacing: 1.2 }
        }
        Grid {
            columns: 6
            spacing: ui.px(10)
            Repeater {
                model: picker.accents
                Rectangle {
                    required property string modelData
                    width: ui.px(35); height: width; radius: width / 2
                    color: "transparent"
                    border { width: Math.max(2, ui.px(2)); color: picker.same(modelData, picker.primary) ? picker.fg : "transparent" }
                    Rectangle {
                        anchors.centerIn: parent
                        width: parent.width - ui.px(9); height: width; radius: width / 2
                        color: parent.modelData
                    }
                    MouseArea { anchors.fill: parent; onClicked: picker.picked(parent.modelData, picker.base) }
                }
            }
        }

        // any hue
        Item {
            width: parent.width; height: ui.px(22)
            Rectangle {
                id: bar
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width; height: ui.px(12); radius: height / 2
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0; color: Util.hsl(0, 0.82, 0.56) }
                    GradientStop { position: 0.167; color: Util.hsl(60, 0.82, 0.56) }
                    GradientStop { position: 0.333; color: Util.hsl(120, 0.82, 0.56) }
                    GradientStop { position: 0.5; color: Util.hsl(180, 0.82, 0.56) }
                    GradientStop { position: 0.667; color: Util.hsl(240, 0.82, 0.56) }
                    GradientStop { position: 0.833; color: Util.hsl(300, 0.82, 0.56) }
                    GradientStop { position: 1.0; color: Util.hsl(360, 0.82, 0.56) }
                }
            }
            Rectangle {
                x: Util.toHsl(picker.primary)[0] / 360 * (parent.width - width)
                anchors.verticalCenter: parent.verticalCenter
                width: ui.px(20); height: width; radius: width / 2
                color: picker.primary
                border { width: Math.max(2, ui.px(3)); color: picker.fg }
            }
            MouseArea {
                anchors.fill: parent
                anchors.margins: -ui.px(6)
                function pick(mx) {
                    var f = Math.max(0, Math.min(1, (mx - ui.px(6)) / parent.width));
                    picker.picked(Util.hsl(f * 359.9, 0.82, 0.56), picker.base);
                }
                onPressed: e => pick(e.x)
                onPositionChanged: e => { if (pressed) pick(e.x); }
            }
        }

        Text {
            text: "BACKGROUND"
            color: Util.alpha(picker.fg, 0.6)
            font { family: t.fonts.label; pixelSize: ui.px(10); weight: Font.Medium; letterSpacing: 1.2 }
        }
        Row {
            spacing: ui.px(10)
            Repeater {
                model: picker.grounds
                Rectangle {
                    required property string modelData
                    width: ui.px(35); height: width; radius: width / 2
                    color: "transparent"
                    border { width: Math.max(2, ui.px(2)); color: picker.same(modelData, picker.base) ? picker.fg : "transparent" }
                    Rectangle {
                        anchors.centerIn: parent
                        width: parent.width - ui.px(9); height: width; radius: width / 2
                        color: parent.modelData
                        border { width: 1; color: Util.alpha(picker.fg, 0.35) }
                    }
                    MouseArea { anchors.fill: parent; onClicked: picker.picked(picker.primary, parent.modelData) }
                }
            }
        }

        Rectangle {
            width: resetLabel.implicitWidth + ui.px(28); height: ui.px(32); radius: height / 2
            color: resetArea.containsMouse ? "#2a2a2d" : "#19191c"
            opacity: picker.custom ? 1 : 0.45
            Text {
                id: resetLabel
                anchors.centerIn: parent
                text: "Back to theme colours"
                color: picker.fg
                font { family: t.fonts.label; pixelSize: ui.px(12); weight: Font.Medium }
            }
            MouseArea { id: resetArea; anchors.fill: parent; hoverEnabled: true; enabled: picker.custom; onClicked: picker.reset() }
        }
    }
}
