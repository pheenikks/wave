import QtQuick
import "Util.js" as Util

// One slot on the shelf: a spine that slides out into a full cover when it
// is the selected tape, with two cassettes fanned out behind it.
Item {
    id: tape

    property var game: ({})
    property var t: Util.defaultTheme()
    property bool current: false
    property bool favorite: false
    property bool launching: false
    property real shelfHeight: 400
    property real spineWidth: 56
    property real coverWidth: 256
    property real reveal: 1          // 0..1, intro progress for this slot
    property real speed: 1
    property string base: "#333333"
    property string badge: ""
    property string groupName: ""
    property string coverSource: ""
    property string spineSource: ""
    property string logoSource: ""
    property string iconSource: ""
    property string spineMode: "auto"

    signal clicked()
    signal favoriteClicked()

    readonly property int seed: Util.hash(game.title)
    readonly property real fan: Math.round(shelfHeight * 0.13)
    readonly property int dur: Math.round(280 * speed)
    property real open: current ? 1 : 0   // 0 spine, 1 cover
    Behavior on open { NumberAnimation { duration: tape.dur; easing.type: Easing.OutCubic } }

    width: Math.round(spineWidth + (coverWidth + fan - spineWidth) * open)
    z: current ? 10 : hover.hovered ? 5 : 0
    opacity: reveal

    HoverHandler { id: hover }

    Item {
        id: stage
        width: parent.width
        height: tape.shelfHeight
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: (1 - tape.reveal) * 40

        readonly property real boxW: Math.round(tape.spineWidth + (tape.coverWidth - tape.spineWidth) * tape.open)
        // spines vary a little in height, like a real mixed shelf
        readonly property real restH: Math.round(tape.shelfHeight * (0.87 + (tape.seed % 6) / 100))
        readonly property real boxH: Math.round(restH + (tape.shelfHeight - restH) * tape.open)
        readonly property real lift: (hover.hovered && !tape.current ? 8 : 0)

        BorderImage {
            visible: tape.open > 0.01
            opacity: tape.open * 0.9
            x: -22; y: stage.height - stage.boxH - 14
            width: stage.boxW + tape.fan + 44; height: stage.boxH + 44
            source: Qt.resolvedUrl("../assets/shadow.png")
            border { left: 32; right: 32; top: 32; bottom: 32 }
        }

        // cassettes behind the cover
        Repeater {
            model: tape.open > 0.01 ? 2 : 0
            Rectangle {
                required property int index
                width: tape.coverWidth * 0.95
                height: tape.shelfHeight * 0.965
                x: stage.boxW - width
                y: stage.height - height - 2
                transformOrigin: Item.BottomLeft
                rotation: (tape.launching ? 0 : (index === 0 ? 7.5 : 3.8)) * tape.open
                Behavior on rotation { NumberAnimation { duration: tape.dur; easing.type: Easing.OutBack } }
                color: index === 0 ? tape.t.colors.accent : tape.t.colors.cassette
                border { width: 1; color: index === 0 ? Util.mix(tape.t.colors.accent, "#000000", 0.25) : "#2c2c2e" }
                Rectangle { // moulded ridge near the edge
                    anchors { right: parent.right; rightMargin: 7; top: parent.top; bottom: parent.bottom; margins: 10 }
                    width: 1
                    color: index === 0 ? "#30000000" : "#30ffffff"
                }
            }
        }

        Item {
            id: box
            x: 0
            y: stage.height - stage.boxH - stage.lift
            Behavior on y { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
            width: stage.boxW
            height: stage.boxH
            clip: true
            scale: tape.launching && tape.current ? 1.035 : 1
            Behavior on scale { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }

            Spine {
                width: tape.spineWidth
                height: stage.restH
                anchors.bottom: parent.bottom
                visible: tape.open < 0.99
                game: tape.game
                t: tape.t
                seed: tape.seed
                base: tape.base
                badge: tape.badge
                spineSource: tape.spineSource
                logoSource: tape.logoSource
                iconSource: tape.iconSource
                coverSource: tape.coverSource
                mode: tape.spineMode
                favorite: tape.favorite
            }

            Loader {
                active: tape.open > 0.01
                anchors.bottom: parent.bottom
                width: tape.coverWidth
                height: tape.shelfHeight
                opacity: Math.min(1, tape.open * 2.2)
                sourceComponent: Cover {
                    game: tape.game
                    t: tape.t
                    seed: tape.seed
                    base: tape.base
                    groupName: tape.groupName
                    coverSource: tape.coverSource
                    logoSource: tape.logoSource
                    iconSource: tape.iconSource
                }
            }
        }

        TapHandler {
            acceptedButtons: Qt.LeftButton
            onTapped: tape.clicked()
        }
        TapHandler {
            acceptedButtons: Qt.RightButton
            onTapped: tape.favoriteClicked()
        }
    }
}
