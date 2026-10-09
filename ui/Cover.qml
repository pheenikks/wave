import QtQuick
import "Util.js" as Util

// The front of a tape box. Shows the game's cover image, or draws a sleeve
// of its own when there is no artwork (or the file can't be read).
Item {
    id: cover

    property var game: ({})
    property var t: Util.defaultTheme()
    property int seed: 0
    property string base: "#333333"
    property string groupName: ""
    property string coverSource: ""
    property string logoSource: ""
    property string iconSource: ""
    property real u: width / 250

    readonly property bool hasImage: coverSource !== "" && img.status === Image.Ready
    readonly property var tapes: t.colors.tapes
    readonly property string second: tapes[(seed >> 5) % tapes.length] === base
                                     ? tapes[((seed >> 5) + 1) % tapes.length]
                                     : tapes[(seed >> 5) % tapes.length]
    readonly property int variant: seed % 3
    readonly property string body: variant === 1 ? t.colors.paper : variant === 2 ? "#141415" : base
    readonly property string inkColor: Util.ink(body)
    readonly property string face: t.fonts.tapes[(seed >> 3) % t.fonts.tapes.length]
    readonly property bool caps: ["Anton", "Bebas Neue", "Archivo Black"].indexOf(face) >= 0

    Rectangle { anchors.fill: parent; color: cover.body }

    // ---- generated sleeve ----------------------------------------------
    Item {
        anchors.fill: parent
        visible: !cover.hasImage
        clip: true

        // motif 0: a big sun dropping off the corner
        Rectangle {
            visible: cover.variant === 0
            width: cover.width * 1.1; height: width; radius: width / 2
            x: cover.width * 0.32; y: cover.height * 0.2
            color: cover.second
        }
        // motif 1: a block of colour under the title
        Rectangle {
            visible: cover.variant === 1
            y: cover.height * 0.56
            width: cover.width; height: cover.height * 0.44
            color: cover.base
        }
        // motif 2: stacked bars, widest at the bottom
        Column {
            visible: cover.variant === 2
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 54 * cover.u
            width: cover.width
            spacing: 7 * cover.u
            Repeater {
                model: 6
                Rectangle {
                    required property int index
                    width: cover.width
                    height: (2 + index * 2.4) * cover.u
                    color: index % 2 ? cover.second : cover.base
                }
            }
        }

        // header strip
        Text {
            x: 16 * cover.u; y: 14 * cover.u
            width: cover.width * 0.6
            elide: Text.ElideRight
            text: cover.groupName.toUpperCase()
            color: cover.inkColor
            font { family: cover.t.fonts.label; pixelSize: Math.round(11 * cover.u); weight: Font.Bold; letterSpacing: 1.2 }
        }
        Text {
            anchors.right: parent.right
            anchors.rightMargin: 16 * cover.u
            y: 14 * cover.u
            text: cover.game.year || ""
            color: cover.inkColor
            font { family: cover.t.fonts.label; pixelSize: Math.round(11 * cover.u); weight: Font.Bold; letterSpacing: 1.2 }
        }
        Rectangle {
            x: 16 * cover.u; y: 34 * cover.u
            width: cover.width - 32 * cover.u; height: 1
            color: Util.alpha(cover.inkColor, 0.7)
        }

        // title: the game's logo if it has one, otherwise set in type
        Image {
            id: logoImg
            x: 20 * cover.u; y: 56 * cover.u
            width: cover.width - 40 * cover.u
            height: cover.height * 0.34
            visible: status === Image.Ready
            source: cover.hasImage ? "" : cover.logoSource
            fillMode: Image.PreserveAspectFit
            asynchronous: true
            sourceSize.width: 768
        }
        Image { // app icon, for games added from the applications list
            id: iconImg
            x: 16 * cover.u; y: 48 * cover.u
            width: 52 * cover.u; height: width
            visible: status === Image.Ready && !logoImg.visible
            source: cover.hasImage ? "" : cover.iconSource
            sourceSize: Qt.size(256, 256)
            asynchronous: true
        }
        Text {
            visible: !logoImg.visible
            x: 16 * cover.u; y: (46 + (iconImg.visible ? 62 : 0)) * cover.u
            width: cover.width - 32 * cover.u
            height: cover.height * (cover.variant === 1 ? 0.46 : 0.5) - (iconImg.visible ? 62 * cover.u : 0)
            text: cover.caps ? String(cover.game.title || "").toUpperCase() : (cover.game.title || "")
            color: cover.inkColor
            wrapMode: Text.WordWrap
            lineHeight: cover.caps ? 0.92 : 0.9
            elide: Text.ElideRight
            fontSizeMode: Text.Fit
            minimumPixelSize: 14
            font {
                family: cover.face
                pixelSize: Math.round((cover.caps ? 62 : 58) * cover.u)
            }
        }

        // footer
        Text {
            anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
            anchors.margins: 16 * cover.u
            elide: Text.ElideRight
            text: String(cover.game.subtitle || "").toUpperCase()
            color: cover.variant === 1 ? Util.ink(cover.base) : cover.inkColor
            font { family: cover.t.fonts.label; pixelSize: Math.round(10 * cover.u); weight: Font.Medium; letterSpacing: 1 }
        }
    }

    Image {
        id: img
        anchors.fill: parent
        visible: cover.hasImage
        source: cover.coverSource
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        sourceSize.height: 1024
    }

    // ---- finish ----------------------------------------------------------
    Rectangle { // fold along the spine side plus a soft sheen
        anchors.fill: parent
        opacity: cover.t.effects.gloss
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.0; color: "#50000000" }
            GradientStop { position: 0.035; color: "#30ffffff" }
            GradientStop { position: 0.07; color: "#00ffffff" }
            GradientStop { position: 0.8; color: "#00000000" }
            GradientStop { position: 1.0; color: "#40000000" }
        }
    }
    Image {
        anchors.fill: parent
        source: Qt.resolvedUrl("../assets/wear.png")
        opacity: cover.t.effects.wear * 0.8
        mirror: (cover.seed & 1) === 1
        smooth: true
    }
}
