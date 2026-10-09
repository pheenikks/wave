import QtQuick
import "Util.js" as Util

// The narrow edge of a tape box. Uses a spine image when the game has one,
// a slice of the cover when asked to, and otherwise draws its own design
// (layout, typeface and colour are picked from a hash of the title, so a
// game always gets the same spine).
Item {
    id: spine

    property var game: ({})
    property var t: Util.defaultTheme()
    property int seed: 0
    property string base: "#333333"     // box colour
    property string badge: ""           // short group label
    property string spineSource: ""
    property string coverSource: ""
    property string logoSource: ""       // transparent title logo, replaces the text
    property string iconSource: ""       // square app icon, shown in place of the badge
    property string mode: "auto"        // auto | generated | cover
    property bool favorite: false
    property real u: width / 56         // unit: scales details with spine width

    readonly property bool hasImage: spineSource !== "" && spineImg.status === Image.Ready
    readonly property bool useCover: !hasImage && coverSource !== "" && mode !== "generated"
                                     && (mode === "cover" || mode === "auto")
                                     && coverImg.status === Image.Ready
    readonly property bool generated: !hasImage && !useCover
    readonly property bool hasLogo: logoSource !== "" && logoImg.status === Image.Ready

    readonly property int variant: seed % 5
    readonly property var tapes: t.colors.tapes
    readonly property string second: tapes[(seed >> 5) % tapes.length] === base
                                     ? tapes[((seed >> 5) + 1) % tapes.length]
                                     : tapes[(seed >> 5) % tapes.length]
    readonly property string paper: t.colors.paper
    readonly property string dark: Util.mix(base, "#000000", 0.55)

    readonly property string body: useCover ? "#101010"
                                   : variant === 1 ? "#141415"
                                   : variant === 2 ? paper
                                   : variant === 4 ? dark
                                   : base
    readonly property string bodyInk: useCover ? "#f4f1ea" : Util.ink(body)
    readonly property string titleInk: generated && variant === 2 ? Util.mix(base, "#000000", Util.luminance(base) > 0.5 ? 0.45 : 0.1)
                                                                : bodyInk

    readonly property string face: t.fonts.tapes[(seed >> 3) % t.fonts.tapes.length]
    readonly property bool caps: ["Anton", "Bebas Neue", "Archivo Black"].indexOf(face) >= 0
    readonly property real topH: Math.round(height * 0.2)
    readonly property real botH: Math.round(height * (variant === 3 ? 0.36 : 0.17))

    Rectangle { anchors.fill: parent; color: spine.body }

    Image {
        id: coverImg
        anchors.fill: parent
        visible: spine.useCover
        source: spine.hasImage || spine.mode === "generated" ? "" : spine.coverSource
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        sourceSize.height: 512
    }
    Rectangle { // scrim so the title stays readable over artwork
        anchors.fill: parent
        visible: spine.useCover
        gradient: Gradient {
            GradientStop { position: 0.0; color: "#b0000000" }
            GradientStop { position: 0.5; color: "#70000000" }
            GradientStop { position: 1.0; color: "#c0000000" }
        }
    }

    // ---- generated layouts -------------------------------------------
    Item {
        anchors.fill: parent
        visible: spine.generated

        // 1: coloured head on a black box
        Rectangle {
            visible: spine.variant === 1
            width: parent.width; height: spine.topH
            color: spine.base
        }
        // 1: three retro stripes
        Column {
            visible: spine.variant === 1
            y: parent.height - spine.botH - 22 * spine.u
            width: parent.width
            spacing: Math.round(2 * spine.u)
            Repeater {
                model: [spine.base, spine.second, spine.paper]
                Rectangle { required property string modelData; width: parent.width; height: Math.round(4 * spine.u); color: modelData }
            }
        }
        // 2 and 3: coloured foot
        Rectangle {
            visible: spine.variant === 2 || spine.variant === 3
            anchors.bottom: parent.bottom
            width: parent.width; height: spine.botH
            color: spine.variant === 2 ? spine.base : spine.dark
        }
        // 3: side stripe
        Rectangle {
            visible: spine.variant === 3
            x: Math.round(5 * spine.u); width: Math.round(3 * spine.u); height: parent.height
            color: spine.second
            opacity: 0.9
        }
        // 4: inset frame
        Rectangle {
            visible: spine.variant === 4
            anchors.fill: parent
            anchors.margins: Math.round(5 * spine.u)
            color: "transparent"
            border { width: 1; color: Util.alpha(spine.bodyInk, 0.55) }
        }
        // 0: hairlines
        Repeater {
            model: spine.variant === 0 ? [spine.topH, spine.topH + 3 * spine.u, spine.height - spine.botH] : []
            Rectangle {
                required property real modelData
                x: 6 * spine.u; y: modelData
                width: spine.width - 12 * spine.u; height: 1
                color: Util.alpha(spine.bodyInk, 0.6)
            }
        }
    }

    // ---- badge (top) ---------------------------------------------------
    Item {
        id: head
        visible: !spine.hasImage && (spine.badge !== "" || iconImg.visible)
        width: parent.width; height: spine.topH
        readonly property string inkColor: spine.generated && spine.variant === 1 ? Util.ink(spine.base) : spine.bodyInk

        Image {
            id: iconImg
            anchors.centerIn: parent
            width: Math.round(Math.min(parent.width - 16 * spine.u, parent.height - 14 * spine.u)); height: width
            visible: status === Image.Ready
            source: spine.hasImage ? "" : spine.iconSource
            sourceSize: Qt.size(128, 128)
            asynchronous: true
        }
        Rectangle {
            visible: !iconImg.visible
            anchors.centerIn: parent
            width: parent.width - 14 * spine.u
            height: Math.round(17 * spine.u)
            color: "transparent"
            border { width: 1; color: Util.alpha(head.inkColor, 0.75) }
            Text {
                anchors.fill: parent
                anchors.margins: 2 * spine.u
                text: spine.badge.toUpperCase()
                color: head.inkColor
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                fontSizeMode: Text.Fit
                minimumPixelSize: 5
                font { family: spine.t.fonts.label; pixelSize: Math.round(10 * spine.u); weight: Font.Bold; letterSpacing: 0.5 }
            }
        }
    }

    // ---- title (reads top to bottom) ------------------------------------
    Image {
        id: logoImg
        visible: spine.hasLogo && !spine.hasImage
        anchors.centerIn: parent
        anchors.verticalCenterOffset: (spine.topH - spine.botH) / 2
        rotation: 90
        width: spine.height - spine.topH - spine.botH - 20 * spine.u
        height: spine.width - 14 * spine.u
        source: spine.hasImage ? "" : spine.logoSource
        fillMode: Image.PreserveAspectFit
        asynchronous: true
        sourceSize.width: 512
    }
    Text {
        visible: !spine.hasImage && !spine.hasLogo
        anchors.centerIn: parent
        anchors.verticalCenterOffset: (spine.topH - spine.botH) / 2
        rotation: 90
        width: spine.height - spine.topH - spine.botH - 16 * spine.u
        height: spine.width - 10 * spine.u
        text: spine.caps ? String(spine.game.title || "").toUpperCase() : (spine.game.title || "")
        color: spine.titleInk
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
        maximumLineCount: 1
        fontSizeMode: Text.Fit
        minimumPixelSize: 9
        font {
            family: spine.face
            pixelSize: Math.round((spine.caps ? 30 : 27) * spine.u)
            letterSpacing: spine.caps ? 1 : 0
        }
    }

    // ---- year (bottom) -------------------------------------------------
    Text {
        visible: !spine.hasImage && !!spine.game.year
        anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom }
        anchors.bottomMargin: Math.round((spine.variant === 3 ? spine.height * 0.17 : spine.botH) / 2 - height / 2)
        text: spine.game.year || ""
        color: spine.generated && (spine.variant === 2 || spine.variant === 3)
               ? Util.ink(spine.variant === 2 ? spine.base : spine.dark) : spine.bodyInk
        font { family: spine.t.fonts.label; pixelSize: Math.round(11 * spine.u); weight: Font.Medium; letterSpacing: 0.5 }
    }

    Image {
        id: spineImg
        anchors.fill: parent
        visible: spine.hasImage
        source: spine.spineSource
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        sourceSize.height: 768
    }

    // ---- finish: gloss, edges, wear ------------------------------------
    Rectangle { // plastic sheen across the box
        anchors.fill: parent
        opacity: spine.t.effects.gloss
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.0; color: "#38ffffff" }
            GradientStop { position: 0.12; color: "#00ffffff" }
            GradientStop { position: 0.7; color: "#00000000" }
            GradientStop { position: 1.0; color: "#70000000" }
        }
    }
    Image {
        anchors.fill: parent
        source: Qt.resolvedUrl("../assets/wear.png")
        opacity: spine.t.effects.wear
        mirror: (spine.seed & 1) === 1
        rotation: (spine.seed & 2) ? 180 : 0
        smooth: true
    }
    Rectangle { // favourite marker: a small accent tab on the top edge
        visible: spine.favorite
        anchors.horizontalCenter: parent.horizontalCenter
        width: Math.round(14 * spine.u); height: Math.round(5 * spine.u)
        color: spine.t.colors.accent
    }
}
