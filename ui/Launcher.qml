import QtQuick
import "Util.js" as Util

// The whole Wave interface. Plain QtQuick: everything that needs Quickshell
// (windowing, files, launching) lives in shell.qml and talks to this through
// properties and signals.
FocusScope {
    id: root

    // ---- inputs --------------------------------------------------------
    property var config: ({})
    property var theme: ({})
    property var games: []
    property var stats: ({})         // { favorites: [], plays: {}, last: {} }
    property string startId: ""      // game to select when the launcher opens
    property string homeDir: ""
    property string baseDir: ""      // relative artwork paths resolve against this
    property string notice: ""       // shown in the footer (errors, first-run hint)
    property bool active: false      // true while the launcher is on screen
    property var apps: []            // installed applications, for the add sheet

    signal launchRequested(var game)
    signal closeRequested()
    signal favoriteToggled(string id)
    signal selectionChanged(string id)
    signal addRequested(var entry)
    signal removeRequested(string id)
    signal primeToggled(string id)
    signal configEdited(string key, var value)   // a top-level config key was changed in the UI

    // ---- resolved settings ---------------------------------------------
    readonly property var cfg: Util.merge(Util.defaultConfig(), config)
    readonly property var t: Util.resolveTheme(theme, cfg)
    // accent colour made safe for small text (a deep accent on a dark panel is hard to read)
    readonly property string accentText: Util.readable(t.colors.accent, t.colors.panel, t.colors.text)
    readonly property real s: cfg.scale * Math.max(0.6, Math.min(2.5, height / 1080))
    function px(v) { return Math.round(v * s); }

    readonly property bool glass: t.style.glass
    readonly property bool hero: t.style.hero
    readonly property bool dockOn: cfg.features.dock
    function rad(h) { return Math.min(t.style.radius * s, h / 2); }   // corner radius for a control of height h

    readonly property real speed: 1 / Math.max(0.1, cfg.animation.speed)
    readonly property real shelfHeight: Math.round(Math.min(cfg.shelf.height * s, panel.height * 0.5))
    readonly property real spineWidth: Math.round(shelfHeight * cfg.shelf.spineWidth / cfg.shelf.height)
    readonly property real coverWidth: Math.round(shelfHeight * cfg.shelf.coverAspect)

    // ---- state ---------------------------------------------------------
    property string group: "ALL"
    property string query: ""
    property bool searching: false
    property string sortOverride: ""
    property string selectedId: ""
    property bool launching: false
    property bool adding: false       // the "add a game" sheet is open
    property string removing: ""      // id waiting for a second Delete press
    property string flyout: ""        // "" | "colors" | "settings": what the side panel's drawer shows
    property string drawerPage: "settings"   // last page, kept while the drawer slides shut
    property real drawer: flyout !== "" ? 1 : 0
    Behavior on drawer { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
    onFlyoutChanged: if (flyout) drawerPage = flyout
    property real reveal: 1
    property double now: Date.now()

    readonly property string sortMode: sortOverride || cfg.sort
    readonly property var favorites: stats.favorites || []
    readonly property var groups: {
        var out = ["ALL"];
        if (favorites.length)
            out.push("★");
        return out.concat(Util.groupsOf(games, cfg.groupOrder));
    }
    // a search looks through the whole library, whatever tab is open
    readonly property var shown: Util.view(games, { group: query ? "ALL" : group, query: query, sort: sortMode, stats: stats })
    readonly property var current: shown[shelf.currentIndex] || null
    readonly property string currentId: Util.gameId(current)

    onShownChanged: refresh()
    onGroupsChanged: if (groups.indexOf(group) < 0) group = "ALL"
    onActiveChanged: if (active) wake()
    Component.onCompleted: { refresh(); if (active) wake(); }

    function wake() {
        now = Date.now();
        launching = false;
        adding = false;
        flyout = "";
        removing = "";
        searching = false;
        query = "";
        if (cfg.startOn === "last" && startId)
            selectedId = startId;
        else if (cfg.startOn === "first")
            selectedId = "";
        refresh();
        catcher.forceActiveFocus();
        if (cfg.animation.intro) {
            reveal = 0;
            intro.restart();
        } else {
            reveal = 1;
        }
    }

    // Swap the shelf's model while keeping the same game selected.
    function refresh() {
        var idx = 0;
        for (var i = 0; i < shown.length; i++)
            if (Util.gameId(shown[i]) === selectedId) { idx = i; break; }
        var d = shelf.highlightMoveDuration;
        shelf.highlightMoveDuration = 0;
        shelf.model = shown;
        shelf.currentIndex = idx;
        shelf.highlightMoveDuration = d;
        selectedId = Util.gameId(shown[idx]);
    }

    function select(i) {
        if (!shown.length)
            return;
        var n = shown.length;
        i = cfg.wrap ? ((i % n) + n) % n : Math.max(0, Math.min(n - 1, i));
        shelf.currentIndex = i;
        selectedId = Util.gameId(shown[i]);
        selectionChanged(selectedId);
    }
    function move(d) { select(shelf.currentIndex + d); }

    function cycleGroup(step) {
        var i = groups.indexOf(group);
        group = groups[(i + step + groups.length) % groups.length];
    }
    function cycleSort() {
        var modes = ["manual", "title", "year", "recent", "plays"];
        sortOverride = modes[(modes.indexOf(sortMode) + 1) % modes.length];
    }

    function launch() {
        if (!current || launching)
            return;
        if (!current.exec) {
            nudge.restart();
            return;
        }
        launching = true;
        launchRequested(current);
        leave.restart();
    }

    function dockAction(id) {
        if (id !== "colors" && id !== "settings")
            flyout = "";
        switch (id) {
        case "add": startAdding(); break;
        case "search": searching = !searching; if (!searching) query = ""; break;
        case "sort": cycleSort(); break;
        case "fav": if (current) favoriteToggled(currentId); break;
        case "gpu": if (current) primeToggled(currentId); break;
        case "remove": askRemove(); break;
        case "colors": case "settings": flyout = flyout === id ? "" : id; break;
        }
    }

    function startAdding() {
        flyout = "";
        adding = true;
        sheet.open();
    }
    function finishAdding(entry) {
        var id = Util.gameId(entry);
        var exists = false;
        for (var i = 0; i < games.length; i++)
            if (Util.gameId(games[i]) === id)
                exists = true;
        // show the new tape: leave any search or tab it would be hidden in
        query = "";
        searching = false;
        if (group !== "ALL" && entry.group !== group)
            group = "ALL";
        selectedId = id;
        if (!exists)
            addRequested(entry);
        adding = false;
        refresh();
        selectionChanged(id);
        catcher.forceActiveFocus();
    }
    function askRemove() {
        if (!current)
            return;
        if (removing === currentId) {
            removing = "";
            removeRequested(currentId);
        } else {
            removing = currentId;
            forget.restart();
        }
    }
    Timer { id: forget; interval: 3000; onTriggered: root.removing = "" }

    function groupInfo(g) { return (cfg.groups && cfg.groups[g]) || {}; }
    function baseColor(g) {
        var tapes = t.colors.tapes;
        return g.color || groupInfo(g.group).color || tapes[Util.hash(g.title) % tapes.length];
    }
    function slotReveal(i) {
        var d = Math.abs(i - shelf.currentIndex);
        var p = Math.max(0, Math.min(1, reveal * 2.4 - d * 0.11));
        return 1 - Math.pow(1 - p, 3);
    }
    function art(p) { return Util.resolvePath(p, homeDir, baseDir); }

    NumberAnimation { id: intro; target: root; property: "reveal"; from: 0; to: 1; duration: 900 * root.speed }
    Timer {
        id: leave
        interval: 420
        onTriggered: {
            if (root.cfg.closeOnLaunch)
                root.closeRequested();
            root.launching = false;
        }
    }

    // ---- bundled typefaces ---------------------------------------------
    FontLoader { source: Qt.resolvedUrl("../assets/fonts/InstrumentSerif-Regular.ttf") }
    FontLoader { source: Qt.resolvedUrl("../assets/fonts/InstrumentSerif-Italic.ttf") }
    FontLoader { source: Qt.resolvedUrl("../assets/fonts/SpaceGrotesk.ttf") }
    FontLoader { source: Qt.resolvedUrl("../assets/fonts/Montserrat-Medium.ttf") }
    FontLoader { source: Qt.resolvedUrl("../assets/fonts/Montserrat-SemiBold.ttf") }
    FontLoader { source: Qt.resolvedUrl("../assets/fonts/Montserrat-Black.ttf") }
    FontLoader { source: Qt.resolvedUrl("../assets/fonts/SpaceMono-Regular.ttf") }
    FontLoader { source: Qt.resolvedUrl("../assets/fonts/Anton-Regular.ttf") }
    FontLoader { source: Qt.resolvedUrl("../assets/fonts/BebasNeue-Regular.ttf") }
    FontLoader { source: Qt.resolvedUrl("../assets/fonts/DMSerifDisplay-Regular.ttf") }
    FontLoader { source: Qt.resolvedUrl("../assets/fonts/ArchivoBlack-Regular.ttf") }
    FontLoader { source: Qt.resolvedUrl("../assets/fonts/CaveatBrush-Regular.ttf") }

    // ---- keyboard ------------------------------------------------------
    focus: true
    Item { id: catcher; focus: true } // holds focus whenever the add sheet is closed; keys bubble up to root
    Keys.onPressed: e => {
        var ctrl = e.modifiers & Qt.ControlModifier;
        if (root.adding)
            return;
        if (root.flyout && e.key === Qt.Key_Escape) {
            root.flyout = "";
            e.accepted = true;
            return;
        }
        if (root.searching) {
            if (e.key === Qt.Key_Escape) {
                root.searching = false;
                root.query = "";
            } else if (e.key === Qt.Key_Backspace) {
                if (root.query === "")
                    root.searching = false;
                root.query = ctrl ? "" : root.query.slice(0, -1);
            } else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) {
                root.launch();
            } else if (e.key === Qt.Key_Left || e.key === Qt.Key_Up) {
                root.move(-1);
            } else if (e.key === Qt.Key_Right || e.key === Qt.Key_Down) {
                root.move(1);
            } else if (e.key === Qt.Key_Tab) {
                root.cycleGroup(1);
            } else if (e.key === Qt.Key_Backtab) {
                root.cycleGroup(-1);
            } else if (e.text.length === 1 && e.text.charCodeAt(0) >= 32 && !ctrl) {
                root.query += e.text;
            } else {
                return;
            }
            e.accepted = true;
            return;
        }
        switch (e.key) {
        case Qt.Key_Left: case Qt.Key_H: case Qt.Key_A: root.move(-1); break;
        case Qt.Key_Right: case Qt.Key_L: case Qt.Key_D: root.move(1); break;
        case Qt.Key_PageUp: root.select(Math.max(0, shelf.currentIndex - 6)); break;
        case Qt.Key_PageDown: root.select(Math.min(root.shown.length - 1, shelf.currentIndex + 6)); break;
        case Qt.Key_Home: root.select(0); break;
        case Qt.Key_End: root.select(root.shown.length - 1); break;
        case Qt.Key_G: root.select((e.modifiers & Qt.ShiftModifier) ? root.shown.length - 1 : 0); break;
        case Qt.Key_Tab: case Qt.Key_BracketRight: root.cycleGroup(1); break;
        case Qt.Key_Backtab: case Qt.Key_BracketLeft: root.cycleGroup(-1); break;
        case Qt.Key_Return: case Qt.Key_Enter: case Qt.Key_Space: root.launch(); break;
        case Qt.Key_F: if (root.current) root.favoriteToggled(root.currentId); break;
        case Qt.Key_S: root.cycleSort(); break;
        case Qt.Key_R: if (root.shown.length) root.select(Math.floor(Math.random() * root.shown.length)); break;
        case Qt.Key_Slash: root.searching = true; break;
        case Qt.Key_N: case Qt.Key_Plus: case Qt.Key_Insert: root.startAdding(); break;
        case Qt.Key_Delete: root.askRemove(); break;
        case Qt.Key_P: if (root.current) root.primeToggled(root.currentId); break;
        case Qt.Key_C: root.dockAction("colors"); break;
        case Qt.Key_Comma: case Qt.Key_O: root.dockAction("settings"); break;
        case Qt.Key_Escape: case Qt.Key_Q: root.closeRequested(); break;
        default:
            if (ctrl && e.key === Qt.Key_F) { root.searching = true; break; }
            return;
        }
        e.accepted = true;
    }

    // ---- backdrop ------------------------------------------------------
    Rectangle {
        anchors.fill: parent
        color: root.t.colors.backdrop
        opacity: root.t.colors.backdropOpacity
    }
    MouseArea { anchors.fill: parent; onClicked: root.closeRequested() }

    // ---- panel ---------------------------------------------------------
    Rectangle {
        id: panel
        anchors.fill: parent
        anchors.margins: Math.round(Math.min(parent.width, parent.height) * root.t.sizes.panelMargin)
        color: root.t.colors.panel
        radius: root.t.sizes.panelRadius
        border { width: 1; color: root.t.colors.panelBorder }
        clip: true
        opacity: root.launching ? 0 : Math.min(1, root.reveal * 4)
        scale: root.launching ? 1.015 : 0.985 + 0.015 * Math.min(1, root.reveal * 3)
        Behavior on opacity { enabled: root.launching; NumberAnimation { duration: 380 } }
        Behavior on scale { enabled: root.launching; NumberAnimation { duration: 380 } }

        readonly property real pad: root.px(30)

        MouseArea { anchors.fill: parent; acceptedButtons: Qt.AllButtons } // swallow clicks

        // ---- glass themes: gradient, waterline and the big title ----
        Rectangle {
            anchors.fill: parent
            visible: !!root.t.colors.panelTop
            radius: panel.radius
            border { width: 1; color: root.t.colors.panelBorder }
            gradient: Gradient {
                GradientStop { position: 0.0; color: root.t.colors.panelTop || root.t.colors.panel }
                GradientStop { position: 0.55; color: Util.mix(root.t.colors.panelTop || root.t.colors.panel, root.t.colors.panel, 0.75) }
                GradientStop { position: 1.0; color: root.t.colors.panel }
            }
        }
        Scene {
            anchors.fill: parent
            visible: root.t.style.scene
            ui: root
            level: heroBox.level
            radius: panel.radius
            motion: root.cfg.features.motion
            running: root.active && !root.adding
        }
        Item {
            id: heroBox
            visible: root.hero
            y: root.px(22)
            width: parent.width
            readonly property real size: Math.round(panel.height * 0.14)
            readonly property real half: Math.round(heroA.implicitHeight * 0.54)
            readonly property real level: y + half      // where the water starts

            Item { // above the water: dark
                width: parent.width; height: heroBox.half
                clip: true
                Text {
                    id: heroA
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: root.cfg.title
                    color: Util.mix(root.t.colors.panel, "#000000", 0.2)
                    opacity: 0.9
                    font { family: root.t.fonts.hero; pixelSize: heroBox.size; weight: Font.Black; letterSpacing: root.px(4) }
                }
            }
            Item { // below: seen through it
                y: heroBox.half
                width: parent.width; height: heroA.implicitHeight - heroBox.half
                clip: true
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: -heroBox.half
                    text: root.cfg.title
                    color: root.t.colors.text
                    opacity: 0.3
                    font: heroA.font
                }
            }
        }
        Canvas { // the surface
            id: water
            visible: root.hero
            anchors.fill: parent
            property real level: heroBox.level
            property string deep: root.t.colors.panel
            property string light: root.t.colors.text
            onLevelChanged: requestPaint()
            onDeepChanged: requestPaint()
            onLightChanged: requestPaint()
            onWidthChanged: requestPaint()
            onPaint: {
                var c = getContext("2d");
                c.reset();
                var w = width;
                function wave(x, k, ph, amp) {
                    return level + Math.sin(x / (w * 0.045 * k) + ph) * root.px(4 * amp) + Math.sin(x / (w * 0.017 * k) + 1.3 + ph) * root.px(2 * amp);
                }
                function trace(k, ph, amp, dy) {
                    c.beginPath();
                    c.moveTo(0, wave(0, k, ph, amp) + dy);
                    for (var x = 6; x <= w + 6; x += 6)
                        c.lineTo(x, wave(x, k, ph, amp) + dy);
                }
                // depth under the surface
                var g = c.createLinearGradient(0, level, 0, level + root.px(280));
                g.addColorStop(0, Util.alpha(deep, 0.46));
                g.addColorStop(1, Util.alpha(deep, 0));
                trace(1, 0, 1, 0);
                c.lineTo(w, level + root.px(280)); c.lineTo(0, level + root.px(280)); c.closePath();
                c.fillStyle = g; c.fill();
                // light caught just under it
                g = c.createLinearGradient(0, level, 0, level + root.px(30));
                g.addColorStop(0, Util.alpha(light, 0.2));
                g.addColorStop(1, Util.alpha(light, 0));
                trace(1, 0, 1, 0);
                c.lineTo(w, level + root.px(30)); c.lineTo(0, level + root.px(30)); c.closePath();
                c.fillStyle = g; c.fill();
                // a second, fainter swell behind the main line
                trace(1.6, 2.2, 1.5, root.px(7));
                c.strokeStyle = Util.alpha(light, 0.16); c.lineWidth = Math.max(1, root.px(1)); c.stroke();
                trace(1, 0, 1, 0);
                c.strokeStyle = Util.alpha(light, 0.62); c.lineWidth = Math.max(1, root.px(2)); c.stroke();
            }
        }

        Rectangle { // the panel's edge, redrawn over the scenery
            anchors.fill: parent
            visible: !!root.t.colors.panelTop
            color: "transparent"
            radius: panel.radius
            border { width: 1; color: root.t.colors.panelBorder }
        }

        // ---- header ----
        Rectangle {
            id: back
            x: panel.pad; y: panel.pad
            width: backLabel.implicitWidth + root.px(root.glass ? 26 : 14); height: root.px(root.glass ? 30 : 22)
            radius: root.rad(height)
            color: backArea.containsMouse ? root.t.colors.text : "transparent"
            border { width: 1; color: root.t.colors.text }
            Label {
                id: backLabel
                ui: root
                anchors.centerIn: parent
                text: "Esc / Close"
                color: backArea.containsMouse ? root.t.colors.panel : root.t.colors.text
            }
            MouseArea { id: backArea; anchors.fill: parent; hoverEnabled: true; onClicked: root.closeRequested() }
        }

        Rectangle {
            id: plus
            visible: !root.dockOn      // the side panel has this button otherwise
            radius: root.rad(height)
            x: back.x + back.width + root.px(8); y: back.y
            width: plusLabel.implicitWidth + root.px(14); height: back.height
            color: plusArea.containsMouse ? root.t.colors.accent : "transparent"
            border { width: 1; color: plusArea.containsMouse ? root.t.colors.accent : root.accentText }
            Label {
                id: plusLabel
                ui: root
                anchors.centerIn: parent
                text: "+ Add game"
                color: plusArea.containsMouse ? Util.ink(root.t.colors.accent) : root.accentText
            }
            MouseArea { id: plusArea; anchors.fill: parent; hoverEnabled: true; onClicked: root.startAdding() }
        }

        Row {
            visible: !root.hero        // the big title replaces the small wordmark
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: back.verticalCenter
            spacing: root.px(9)
            Rectangle {
                width: root.px(26); height: root.px(26)
                color: root.t.colors.accent
                anchors.verticalCenter: parent.verticalCenter
                Canvas {
                    id: mark
                    anchors.fill: parent
                    property string stroke: root.t.colors.panel
                    onStrokeChanged: requestPaint()
                    onWidthChanged: requestPaint()
                    onPaint: {
                        var c = getContext("2d");
                        c.reset();
                        c.lineWidth = Math.max(2, width * 0.11);
                        c.lineCap = "round";
                        c.strokeStyle = stroke;
                        for (var r = 0; r < 2; r++) {
                            var y0 = height * (0.38 + r * 0.26);
                            c.beginPath();
                            for (var x = 0; x <= 20; x++) {
                                var px = width * (0.18 + 0.64 * x / 20);
                                var py = y0 + Math.sin(x / 20 * Math.PI * 2) * height * 0.09;
                                if (x === 0) c.moveTo(px, py); else c.lineTo(px, py);
                            }
                            c.stroke();
                        }
                    }
                }
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: root.cfg.title
                color: root.accentText
                font { family: root.t.fonts.label; pixelSize: root.px(17); weight: Font.Bold; letterSpacing: root.px(5) }
            }
        }

        Label {
            ui: root
            anchors { right: parent.right; rightMargin: panel.pad; verticalCenter: back.verticalCenter }
            text: {
                var yr = Util.yearRange(root.shown);
                var out = String(root.cfg.tagline).replace("{count}", root.shown.length);
                if (!yr[0])
                    return out.replace(/\s*\/?\s*\{from\}.*$/, "");
                return out.replace("{from}", yr[0]).replace("{to}", yr[1]);
            }
        }

        // ---- group tabs / search ----
        Item {
            id: bar
            anchors.horizontalCenter: parent.horizontalCenter
            y: shelf.y - height - root.px(6)
            width: parent.width; height: root.px(root.glass ? 28 : 22)

            Row {
                anchors.centerIn: parent
                visible: !root.searching
                spacing: root.t.style.radius > 0 ? root.px(6) : -1
                Repeater {
                    model: root.groups
                    Rectangle {
                        id: tab
                        required property string modelData
                        readonly property bool on: modelData === root.group
                        width: tabLabel.implicitWidth + root.px(root.glass ? 28 : 16); height: bar.height
                        radius: root.rad(height)
                        color: on ? root.t.colors.text : tabArea.containsMouse ? Util.alpha(root.t.colors.text, 0.12) : "transparent"
                        border { width: 1; color: on ? root.t.colors.text : root.t.colors.line }
                        z: on ? 1 : 0
                        Label {
                            id: tabLabel
                            ui: root
                            anchors.centerIn: parent
                            text: tab.modelData
                            color: tab.on ? root.t.colors.panel : root.t.colors.text
                        }
                        MouseArea { id: tabArea; anchors.fill: parent; hoverEnabled: true; onClicked: root.group = tab.modelData }
                    }
                }
            }

            Rectangle {
                anchors.centerIn: parent
                visible: root.searching
                width: Math.max(root.px(260), find.implicitWidth + root.px(28)); height: bar.height
                radius: root.rad(height)
                color: root.glass ? Util.alpha(root.t.colors.panel, 0.5) : "transparent"
                border { width: 1; color: root.accentText }
                Row {
                    id: find
                    anchors.centerIn: parent
                    spacing: root.px(8)
                    Label { ui: root; text: "Search /"; color: root.t.colors.muted }
                    Label { ui: root; text: root.query }
                    Rectangle {
                        width: root.px(7); height: root.px(12)
                        anchors.verticalCenter: parent.verticalCenter
                        color: root.t.colors.accent
                        SequentialAnimation on opacity {
                            running: root.searching; loops: Animation.Infinite
                            NumberAnimation { to: 0; duration: 60 } PauseAnimation { duration: 440 }
                            NumberAnimation { to: 1; duration: 60 } PauseAnimation { duration: 440 }
                        }
                    }
                }
            }
        }

        // ---- shelf ----
        ListView {
            id: shelf
            anchors { left: parent.left; right: parent.right }
            y: Math.round((parent.height - height) / 2 - root.px(26) + (root.hero ? root.px(34) : 0))
            height: root.shelfHeight + root.px(84)
            orientation: ListView.Horizontal
            spacing: Math.round(root.cfg.shelf.gap * root.spineWidth / root.cfg.shelf.spineWidth)
            boundsBehavior: Flickable.StopAtBounds
            cacheBuffer: 2400
            highlightRangeMode: ListView.StrictlyEnforceRange
            preferredHighlightBegin: Math.round((width - root.coverWidth - root.shelfHeight * 0.13) / 2)
            preferredHighlightEnd: Math.round((width + root.coverWidth + root.shelfHeight * 0.13) / 2)
            highlightMoveDuration: Math.round(340 * root.speed)
            onMovementEnded: root.select(currentIndex)

            WheelHandler {
                acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                onWheel: e => root.move((e.angleDelta.y || -e.angleDelta.x) < 0 ? 1 : -1)
            }

            delegate: Tape {
                id: slot
                required property var modelData
                required property int index
                height: shelf.height
                game: modelData
                t: root.t
                speed: root.speed
                current: ListView.isCurrentItem
                launching: root.launching
                favorite: root.favorites.indexOf(Util.gameId(modelData)) >= 0
                shelfHeight: root.shelfHeight
                spineWidth: root.spineWidth
                coverWidth: root.coverWidth
                reveal: root.slotReveal(index)
                base: root.baseColor(modelData)
                badge: modelData.group || ""
                groupName: root.groupInfo(modelData.group).name || modelData.group || ""
                coverSource: root.art(modelData.cover)
                spineSource: root.art(modelData.spine)
                iconSource: root.art(modelData.icon)
                logoSource: root.art(modelData.logo)
                spineMode: root.cfg.shelf.spines
                onClicked: current ? root.launch() : root.select(index)
                onFavoriteClicked: root.favoriteToggled(Util.gameId(modelData))
            }
        }

        // fade the shelf out at the panel edges
        Repeater {
            model: 2
            Rectangle {
                required property int index
                visible: !root.t.colors.panelTop   // a flat fade would show against a gradient
                width: root.px(90); height: shelf.height
                y: shelf.y
                x: index ? panel.width - width : 0
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: index ? 1 : 0; color: root.t.colors.panel }
                    GradientStop { position: index ? 0 : 1; color: Util.alpha(root.t.colors.panel, 0) }
                }
            }
        }

        // ---- empty states ----
        Column {
            anchors.centerIn: shelf
            visible: root.shown.length === 0
            spacing: root.px(14)
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.games.length ? "Nothing here" : "The shelf is empty"
                color: root.t.colors.text
                font { family: root.t.fonts.title; pixelSize: root.px(root.t.sizes.title); weight: root.t.fonts.titleWeight }
            }
            Label {
                ui: root
                anchors.horizontalCenter: parent.horizontalCenter
                color: root.t.colors.muted
                text: root.games.length ? (root.query ? "No title matches \u201c" + root.query + "\u201d" : "No games in this group")
                                        : "Add your first game to get started"
            }
            Rectangle {
                visible: root.games.length === 0
                anchors.horizontalCenter: parent.horizontalCenter
                width: bigLabel.implicitWidth + root.px(40); height: root.px(42)
                radius: root.rad(height)
                color: bigArea.containsMouse ? Util.mix(root.t.colors.accent, "#ffffff", 0.15) : root.t.colors.accent
                Label { id: bigLabel; ui: root; anchors.centerIn: parent; size: 12; text: "+ Add a game"; color: Util.ink(root.t.colors.accent) }
                MouseArea { id: bigArea; anchors.fill: parent; hoverEnabled: true; onClicked: root.startAdding() }
            }
            Label {
                ui: root
                visible: root.games.length === 0
                anchors.horizontalCenter: parent.horizontalCenter
                size: root.t.sizes.label - 1
                color: root.t.colors.muted
                text: "or press N"
            }
        }

        // ---- title block ----
        Rectangle { // frosted card behind it, in glass themes
            visible: root.glass && !!root.current
            anchors.centerIn: info
            width: Math.max(root.px(400), Math.min(info.width, titleText.implicitWidth + root.px(100)))
            height: info.height + root.px(36)
            radius: root.px(22)
            color: Util.alpha(root.t.colors.text, 0.09)
            border { width: 1; color: Util.alpha(root.t.colors.text, 0.3) }
        }
        Column {
            id: info
            anchors.horizontalCenter: parent.horizontalCenter
            y: shelf.y + shelf.height + root.px(root.glass ? 14 : 2)
            width: parent.width - root.px(220)
            spacing: root.px(9)
            visible: !!root.current
            transform: Translate { id: shake }

            Text {
                id: titleText
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
                text: root.current ? root.current.title : ""
                color: root.t.colors.text
                font { family: root.t.fonts.title; pixelSize: root.px(root.t.sizes.title); weight: root.t.fonts.titleWeight }
            }
            Label {
                ui: root
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
                color: root.accentText
                text: root.current ? (root.current.subtitle || root.groupInfo(root.current.group).name || root.current.group || "") : ""
            }
            Label {
                ui: root
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.current && root.current.year ? root.current.year : ""
            }
            Label {
                ui: root
                anchors.horizontalCenter: parent.horizontalCenter
                color: root.t.colors.muted
                size: root.t.sizes.label - 1
                text: {
                    if (!root.current)
                        return "";
                    var id = root.currentId;
                    var n = (root.stats.plays || {})[id] || 0;
                    if (root.removing === id)
                        return "Press Delete again to take this off the shelf";
                    var parts = [];
                    if (root.favorites.indexOf(id) >= 0)
                        parts.push("★ Favorite");
                    if (root.current.prime || root.cfg.primeAll)
                        parts.push("Dedicated GPU");
                    if (!root.current.exec)
                        parts.push("No launch command");
                    else if (n)
                        parts.push("Played " + n + (n === 1 ? " time" : " times") + " / last " + Util.ago((root.stats.last || {})[id], root.now));
                    else
                        parts.push("Never played");
                    return parts.join("  ·  ");
                }
            }
        }
        SequentialAnimation {
            id: nudge
            NumberAnimation { target: shake; property: "x"; to: 10; duration: 50 }
            NumberAnimation { target: shake; property: "x"; to: -8; duration: 70 }
            NumberAnimation { target: shake; property: "x"; to: 0; duration: 90 }
        }

        // ---- arrows ----
        Repeater {
            model: 2
            Label {
                required property int index
                ui: root
                size: 16
                text: index ? "→" : "←"
                x: index ? panel.width - panel.pad - width - (root.dockOn ? dock.width + root.px(4) : 0) : panel.pad
                y: info.y + root.px(12)
                opacity: arrowArea.containsMouse ? 1 : 0.75
                visible: root.shown.length > 1
                MouseArea {
                    id: arrowArea
                    anchors.fill: parent; anchors.margins: -root.px(12)
                    hoverEnabled: true
                    onClicked: root.move(index ? 1 : -1)
                }
            }
        }

        // ---- footer ----
        Label {
            ui: root
            anchors { left: parent.left; bottom: parent.bottom; margins: panel.pad }
            width: parent.width * 0.7
            elide: Text.ElideRight
            size: root.t.sizes.label - 1
            color: root.notice ? root.accentText : root.t.colors.muted
            visible: root.notice !== "" || root.cfg.features.hints
            text: root.notice || (root.searching
                  ? "Type to filter    ← → Browse    Enter Play    Esc Clear"
                  : "← → Browse    Tab Group    / Search    S Sort    F Favorite    P GPU    N Add    Del Remove    Enter Play")
        }
        Label {
            ui: root
            anchors { right: parent.right; bottom: parent.bottom; margins: panel.pad }
            size: root.t.sizes.label - 1
            text: "Sort / " + root.sortMode
            MouseArea { anchors.fill: parent; anchors.margins: -root.px(8); onClicked: root.cycleSort() }
        }

        // ---- side panel and its drawer ----
        MouseArea { // a click anywhere else closes the drawer
            anchors.fill: parent
            visible: root.flyout !== ""
            onClicked: root.flyout = ""
        }
        Item { // the drawer: the side panel widening to the left
            id: drawerBox
            visible: root.dockOn && root.drawer > 0.01
            readonly property real inner: root.px(318)
            x: dock.x - (inner * root.drawer)
            y: dock.y
            width: inner + root.px(44)        // runs on under the dock so the two read as one shape
            height: dock.height
            opacity: Math.min(1, root.drawer * 1.6)
            clip: true

            Rectangle {
                anchors.fill: parent
                radius: root.px(30)
                color: root.t.colors.dock
            }
            MouseArea { anchors.fill: parent; acceptedButtons: Qt.AllButtons }
            ColorPicker {
                visible: root.drawerPage === "colors"
                ui: root
                x: root.px(6); y: root.px(6)
                primary: (root.cfg.palette && root.cfg.palette.primary) || root.t.colors.accent
                base: (root.cfg.palette && root.cfg.palette.base) || root.t.colors.backdrop
                custom: !!(root.cfg.palette && (root.cfg.palette.primary || root.cfg.palette.base))
                onPicked: (primary, base) => root.configEdited("palette", { primary: primary, base: base })
                onReset: root.configEdited("palette", {})
            }
            SettingsPanel {
                visible: root.drawerPage === "settings"
                ui: root
                x: root.px(6); y: root.px(6)
                themes: Util.builtinThemes.indexOf(root.cfg.theme) >= 0 ? Util.builtinThemes : Util.builtinThemes.concat([root.cfg.theme])
                onEdited: (key, value) => root.configEdited(key, value)
            }
            Rectangle { // hairline between drawer and buttons
                x: drawerBox.inner - 1; y: root.px(26)
                width: 1; height: parent.height - root.px(52)
                color: "#2a2a2d"
            }
        }
        Dock {
            id: dock
            visible: root.dockOn
            ui: root
            x: parent.width - width
            y: Math.round((parent.height - height) / 2 - root.px(4))
            labels: root.cfg.features.dockLabels
            items: [
                { id: "add", icon: "plus", label: "Add", on: root.adding },
                { id: "search", icon: "search", label: "Search", on: root.searching },
                { id: "sort", icon: "sort", label: root.sortMode.charAt(0).toUpperCase() + root.sortMode.slice(1), on: root.sortMode !== "manual" },
                { id: "fav", icon: "star", label: "Favorite", on: !!root.current && root.favorites.indexOf(root.currentId) >= 0, color: "#ffd60a", filled: true },
                { id: "gpu", icon: "gpu", label: "GPU", on: !!root.current && !!(root.current.prime || root.cfg.primeAll), color: "#30d158", filled: true },
                { id: "remove", icon: "trash", label: root.removing !== "" && root.removing === root.currentId ? "Sure?" : "Remove",
                  on: root.removing !== "" && root.removing === root.currentId, color: "#ff453a" },
                { id: "colors", icon: "drop", label: "Colours", on: root.flyout === "colors" },
                { id: "settings", icon: "gear", label: "Settings", on: root.flyout === "settings" }
            ]
            onTriggered: id => root.dockAction(id)
        }

        AddSheet {
            id: sheet
            anchors.fill: parent
            visible: root.adding
            ui: root
            apps: root.apps
            groups: Util.groupsOf(root.games, root.cfg.groupOrder)
            homeDir: root.homeDir
            onAccepted: entry => root.finishAdding(entry)
            onClosed: { root.adding = false; catcher.forceActiveFocus(); }
        }

        // ---- surface effects ----
        Image {
            anchors.fill: parent
            source: Qt.resolvedUrl("../assets/vignette.png")
            opacity: root.t.effects.vignette
        }
        Image {
            anchors.fill: parent
            source: Qt.resolvedUrl("../assets/grain.png")
            fillMode: Image.Tile
            opacity: root.t.effects.grain
        }
        Image {
            anchors.fill: parent
            visible: root.t.effects.scanlines > 0
            source: Qt.resolvedUrl("../assets/scanlines.png")
            fillMode: Image.Tile
            opacity: root.t.effects.scanlines
        }
    }
}
