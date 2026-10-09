import QtQuick

// Small uppercase caption text used all over the launcher.
Text {
    property var ui            // the Launcher
    property real size: ui ? ui.t.sizes.label : 11
    color: ui ? ui.t.colors.text : "white"
    font {
        family: ui ? ui.t.fonts.label : "sans-serif"
        pixelSize: ui ? ui.px(size) : size
        weight: Font.Medium
        letterSpacing: 1.3
        capitalization: Font.AllUppercase
    }
}
