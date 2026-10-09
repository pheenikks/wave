import QtQuick
import "Util.js" as Util

// The side panel: a black dock that grows out of the right edge, holding one
// ringed button per action. Colours and settings open a drawer beside it.
Item {
    id: dock

    property var ui                 // the Launcher
    // [{ id, icon, label, on, color, filled }]
    property var items: []
    property bool labels: true
    signal triggered(string id)

    readonly property var t: ui.t
    readonly property real cell: ui.px(labels ? 74 : 58)
    readonly property real fillet: ui.px(26)

    width: ui.px(84)
    height: items.length * cell + ui.px(34)

    // Body: rounded on the left, flowing into the edge with concave curves.
    Canvas {
        id: body
        x: 0; y: -dock.fillet
        width: dock.width; height: dock.height + dock.fillet * 2
        property string fill: dock.t.colors.dock
        onFillChanged: requestPaint()
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        onPaint: {
            var c = getContext("2d");
            c.reset();
            var w = width, f = dock.fillet, h = dock.height, r = Math.min(ui.px(30), w / 2);
            c.fillStyle = fill;
            c.beginPath();
            c.moveTo(w, 0);
            c.quadraticCurveTo(w, f, w - f, f);          // concave shoulder
            c.lineTo(r, f);
            c.quadraticCurveTo(0, f, 0, f + r);          // rounded corner
            c.lineTo(0, f + h - r);
            c.quadraticCurveTo(0, f + h, r, f + h);
            c.lineTo(w - f, f + h);
            c.quadraticCurveTo(w, f + h, w, f + h + f);  // concave foot
            c.closePath();
            c.fill();
        }
    }
    MouseArea { anchors.fill: parent; acceptedButtons: Qt.AllButtons } // clicks don't fall through

    Column {
        y: ui.px(17)
        width: parent.width
        Repeater {
            model: dock.items
            Item {
                id: btn
                required property var modelData
                width: dock.width; height: dock.cell
                readonly property string tint: modelData.on ? (modelData.color || dock.t.colors.accent) : "#3a3a3d"

                Rectangle { // ring
                    id: ring
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: ui.px(4)
                    width: ui.px(46); height: width; radius: width / 2
                    color: area.pressed ? "#2a2a2d" : area.containsMouse ? "#1c1c1f" : "transparent"
                    border { width: Math.max(2, ui.px(3)); color: btn.tint }
                    Behavior on border.color { ColorAnimation { duration: 160 } }
                    scale: area.pressed ? 0.94 : 1
                    Behavior on scale { NumberAnimation { duration: 90 } }
                    Icon {
                        anchors.centerIn: parent
                        width: ui.px(22); height: width
                        name: btn.modelData.icon
                        color: dock.t.colors.dockText
                        filled: !!btn.modelData.filled && !!btn.modelData.on
                    }
                }
                Text {
                    visible: dock.labels
                    anchors { horizontalCenter: parent.horizontalCenter; top: ring.bottom; topMargin: ui.px(5) }
                    text: btn.modelData.label
                    color: btn.modelData.on ? dock.t.colors.dockText : Util.alpha(dock.t.colors.dockText, 0.72)
                    font { family: dock.t.fonts.label; pixelSize: ui.px(10); weight: Font.Medium; letterSpacing: 0.6 }
                }
                MouseArea {
                    id: area
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: dock.triggered(btn.modelData.id)
                }
            }
        }
    }
}
