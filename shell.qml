// Wave: a tape-shelf game launcher for Quickshell (Hyprland and other
// wlroots compositors).
//
//   wave            open or close (bin/wave; starts this if needed)
//   qs -c wave      run it directly, hidden, with logs in the terminal
//
// This file is the only part that needs Quickshell: it owns the window,
// reads and writes files, and starts games. The interface is in ui/.

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "ui"
import "ui/Util.js" as Util

ShellRoot {
    id: root

    readonly property string home: Quickshell.env("HOME") || ""
    readonly property string configDir: (Quickshell.env("XDG_CONFIG_HOME") || home + "/.config") + "/wave"
    readonly property string cacheDir: (Quickshell.env("XDG_CACHE_HOME") || home + "/.cache") + "/wave"
    readonly property string stateDir: (Quickshell.env("XDG_STATE_HOME") || home + "/.local/state") + "/wave"

    property var config: ({})
    property var games: []            // only what is in ~/.config/wave/games.json
    property var steamGames: []       // installed Steam games, found by `wave scan`
    property var steamTools: []       // Proton versions Steam can use
    property string steamDefaultTool: ""
    property var stats: ({})
    property string selected: ""
    property var userTheme: null
    property var builtinTheme: null
    property string themeOverride: "" // set over IPC
    property var errors: ({})         // file name -> message

    readonly property string themeName: themeOverride || config.theme || "wave"
    readonly property string notice: {
        for (var k in errors)
            if (errors[k])
                return k + ": " + errors[k];
        return "";
    }

    function parse(name, text, fallback) {
        var e = Object.assign({}, errors);
        try {
            var v = JSON.parse(text);
            e[name] = "";
            errors = e;
            return v;
        } catch (err) {
            e[name] = String(err.message || err);
            errors = e;
            console.warn("wave: " + name + ": " + err);
            return fallback;
        }
    }

    function expand(p) {
        return String(p).indexOf("~/") === 0 ? home + String(p).slice(1) : String(p);
    }

    function saveStats() {
        var out = Object.assign({}, stats, { selected: selected });
        statsFile.setText(JSON.stringify(out, null, 2) + "\n");
    }

    function launch(g) {
        var cmd = Util.launchCommand(g, config, home, Quickshell.shellDir + "/bin/wave");
        Quickshell.execDetached(["sh", "-c", cmd]);

        var id = Util.gameId(g);
        var next = Object.assign({}, stats);
        next.plays = Object.assign({}, stats.plays);
        next.last = Object.assign({}, stats.last);
        next.plays[id] = (next.plays[id] || 0) + 1;
        next.last[id] = Date.now();
        stats = next;
        selected = id;
        saveStats();
        if (config.quitOnLaunch)
            quitTimer.start(); // give the game and the stats file a moment first
    }
    Timer { id: quitTimer; interval: 900; onTriggered: Qt.quit() }

    // Installed applications, offered in the "add a game" sheet.
    readonly property var apps: {
        var out = [];
        var steamIds = {};
        for (var s = 0; s < steamGames.length; s++) {
            var sg = steamGames[s];
            steamIds[sg.appid] = true;
            out.push({
                name: sg.name, exec: "steam steam://rungameid/" + sg.appid, icon: "",
                cover: sg.cover || "", logo: sg.logo || "", appid: sg.appid, dir: sg.dir || "",
                proton: sg.proton || "",
                comment: "Steam", game: true, source: "steam", group: "Steam"
            });
        }
        try {
            var list = DesktopEntries.applications.values;
            for (var i = 0; i < list.length; i++) {
                var e = list[i];
                var cmd = e.execString || (e.command ? e.command.join(" ") : "");
                if (e.noDisplay || !e.name || !cmd || /\/wave show$/.test(cmd))
                    continue; // (Wave's own menu entry is not a game)
                var m = /steam:\/\/rungameid\/(\d+)/.exec(cmd);
                if (m && steamIds[m[1]])
                    continue; // already listed from the Steam library, with artwork
                var icon = !e.icon ? "" : e.icon.charAt(0) === "/" ? "file://" + e.icon : Quickshell.iconPath(e.icon, true);
                out.push({
                    name: e.name, exec: cmd, icon: icon || "",
                    comment: e.genericName || e.comment || "",
                    game: (e.categories || []).indexOf("Game") >= 0
                });
            }
        } catch (err) {
            console.warn("wave: could not list applications: " + err);
        }
        return out;
    }

    // Change one top-level key of config.json (from the settings and colour panels).
    function setConfig(key, value) {
        var next = Object.assign({}, config);
        next[key] = value;
        config = next;
        configFile.setText(JSON.stringify(next, null, 2) + "\n");
    }

    // Ask the helper to list installed Steam games, then read what it wrote.
    function scanSteam() {
        Quickshell.execDetached([Quickshell.shellDir + "/bin/wave", "scan"]);
        steamTimer.restart();
    }
    Timer { id: steamTimer; interval: 1500; onTriggered: steamFile.reload() }

    function saveGames() {
        gamesFile.setText(JSON.stringify(games, null, 2) + "\n");
    }
    function addGame(entry) {
        games = games.concat([entry]);
        saveGames();
    }
    function removeGame(id) {
        games = games.filter(function (g) { return Util.gameId(g) !== id; });
        saveGames();
    }

    function setCover(id, path) {
        games = games.map(function (g) {
            if (Util.gameId(g) !== id)
                return g;
            var next = Object.assign({}, g);
            if (path)
                next.cover = path;
            else
                delete next.cover;
            return next;
        });
        saveGames();
    }

    function setProton(id, value) {
        games = games.map(function (g) {
            if (Util.gameId(g) !== id)
                return g;
            var next = Object.assign({}, g);
            if (value)
                next.proton = value;
            else
                delete next.proton;
            return next;
        });
        saveGames();
    }

    function togglePrime(id) {
        games = games.map(function (g) {
            if (Util.gameId(g) !== id)
                return g;
            var next = Object.assign({}, g);
            if (g.prime)
                delete next.prime;
            else
                next.prime = true;
            return next;
        });
        saveGames();
    }

    function toggleFavorite(id) {
        var favs = (stats.favorites || []).slice();
        var i = favs.indexOf(id);
        if (i >= 0)
            favs.splice(i, 1);
        else
            favs.push(id);
        stats = Object.assign({}, stats, { favorites: favs });
        saveStats();
    }

    function show() {
        var want = config.monitor || (hypr.item ? hypr.item.focusedMonitor : "");
        if (want) {
            for (var i = 0; i < Quickshell.screens.length; i++)
                if (Quickshell.screens[i].name === want)
                    win.screen = Quickshell.screens[i];
        }
        win.visible = true;
        scanSteam();
    }
    function hide() {
        if (!win.visible)
            return;
        win.visible = false;
        saveStats();
    }

    Component.onCompleted: {
        Quickshell.execDetached(["mkdir", "-p", stateDir, cacheDir, configDir + "/covers", configDir + "/themes"]);
        scanSteam();
    }

    // ---- files ---------------------------------------------------------
    FileView {
        id: steamFile
        path: root.cacheDir + "/steam.json"
        printErrors: false
        onLoaded: {
            try {
                var data = JSON.parse(text());
                if (Array.isArray(data))
                    data = { games: data };   // written by an older Wave
                root.steamGames = data.games || [];
                root.steamTools = data.tools || [];
                root.steamDefaultTool = data.defaultTool || "";
            } catch (err) {
                root.steamGames = [];
            }
        }
    }
    FileView {
        id: configFile
        path: root.configDir + "/config.json"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: root.config = root.parse("config.json", text(), root.config)
    }
    FileView {
        id: gamesFile
        path: root.configDir + "/games.json"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: root.games = root.parse("games.json", text(), root.games)
        onLoadFailed: root.games = []
    }
    FileView {
        id: statsFile
        path: root.stateDir + "/stats.json"
        printErrors: false
        onLoaded: {
            var s = root.parse("stats.json", text(), {});
            root.selected = s.selected || "";
            root.stats = s;
        }
    }
    FileView { // a theme in ~/.config/wave/themes wins over a bundled one
        path: root.configDir + "/themes/" + root.themeName + ".json"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: root.userTheme = root.parse("themes/" + root.themeName + ".json", text(), null)
        onLoadFailed: root.userTheme = null
    }
    FileView {
        path: Quickshell.shellDir + "/themes/" + root.themeName + ".json"
        printErrors: false
        onLoaded: root.builtinTheme = root.parse(root.themeName + ".json", text(), null)
        onLoadFailed: root.builtinTheme = null
    }

    // Focused-monitor lookup; quietly absent without Quickshell's Hyprland module.
    Loader {
        id: hypr
        source: "compat/Hyprland.qml"
    }

    IpcHandler {
        target: "wave"
        function toggle(): void { win.visible ? root.hide() : root.show(); }
        function show(): void { root.show(); }
        function hide(): void { root.hide(); }
        function theme(name: string): void { root.themeOverride = name; }
    }

    // ---- window --------------------------------------------------------
    PanelWindow {
        id: win
        visible: false
        color: "transparent"
        anchors { top: true; bottom: true; left: true; right: true }
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
        WlrLayershell.namespace: "wave"

        // The interface exists only while the window is open (unless "preload"
        // is on), so a hidden Wave holds little more than Quickshell itself.
        Loader {
            anchors.fill: parent
            focus: true
            active: win.visible || !!root.config.preload
            sourceComponent: Component {
                Launcher {
                    active: win.visible
                    config: root.config
                    theme: root.userTheme || root.builtinTheme || ({})
                    games: root.games
                    stats: root.stats
                    startId: root.selected
                    homeDir: root.home
                    baseDir: root.configDir
                    notice: root.notice
                    onLaunchRequested: g => root.launch(g)
                    onCloseRequested: root.hide()
                    onFavoriteToggled: id => root.toggleFavorite(id)
                    onSelectionChanged: id => root.selected = id
                    apps: root.apps
                    onAddRequested: entry => root.addGame(entry)
                    onRemoveRequested: id => root.removeGame(id)
                    onPrimeToggled: id => root.togglePrime(id)
                    onCoverChanged: (id, path) => root.setCover(id, path)
                    onProtonChanged: (id, value) => root.setProton(id, value)
                    steamTools: root.steamTools
                    steamDefaultTool: root.steamDefaultTool
                    onConfigEdited: (key, value) => root.setConfig(key, value)
                }
            }
        }
    }
}
