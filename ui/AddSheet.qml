import QtQuick
import Qt.labs.folderlistmodel
import "Util.js" as Util

// "Add a game": pick an installed app, type a command, or browse to a file,
// then confirm the title. Emits accepted() with a ready games.json entry.
FocusScope {
    id: sheet

    property var ui                    // the Launcher (theme, scale)
    property var apps: []              // [{ name, exec, icon, game, comment }]
    property var groups: []            // existing group names, shown as a hint
    property string homeDir: ""
    property string mode: "apps"       // apps | files | confirm
    property string backTo: "apps"     // where Esc returns to from confirm
    property string folder: homeDir || "/"
    property var files: []             // contents of `folder`
    property var draft: ({})
    property bool primeOn: false       // "run on the dedicated GPU" for the game being added
    property int index: 0

    // "game" adds a game; "cover" only picks an image for an existing one
    property string purpose: "game"
    property string coverFor: ""       // title of the game getting a cover
    property bool hasCover: false      // it already has one (offers "remove")
    readonly property var imageTypes: ["png", "jpg", "jpeg", "webp", "bmp", "gif", "avif"]

    signal accepted(var entry)
    signal coverPicked(string path)    // "" removes the custom cover
    signal closed()

    readonly property var t: ui.t
    readonly property var rows: mode === "files" ? fileRows(input.text) : appRows(input.text)

    function openForCover(title, has) {
        purpose = "cover";
        coverFor = title;
        hasCover = has;
        mode = "files";
        input.text = "";
        index = rows.length > 1 && rows[0].kind === "up" ? 1 : 0;
        input.forceActiveFocus();
    }

    function open() {
        purpose = "game";
        mode = "apps";
        input.text = "";
        index = 0;
        input.forceActiveFocus();
    }

    // ---- building the list -------------------------------------------------
    function appRows(q) {
        var out = [{ kind: "browse", name: "Browse for a game file…", detail: "Pick an executable, script, AppImage or ROM", tag: "" }];
        var words = q.toLowerCase().split(/\s+/).filter(function (w) { return w; });
        var hits = [];
        for (var i = 0; i < apps.length; i++) {
            var a = apps[i];
            var hay = (a.name + " " + (a.comment || "") + " " + (a.exec || "")).toLowerCase();
            var ok = true;
            for (var w = 0; w < words.length; w++)
                if (hay.indexOf(words[w]) < 0) { ok = false; break; }
            if (ok)
                hits.push(a);
        }
        hits.sort(function (a, b) {
            if (!!a.game !== !!b.game)
                return a.game ? -1 : 1;
            if (words.length) { // names starting with the query first
                var x = a.name.toLowerCase().indexOf(words[0]) === 0, y = b.name.toLowerCase().indexOf(words[0]) === 0;
                if (x !== y)
                    return x ? -1 : 1;
            }
            return a.name.localeCompare(b.name);
        });
        for (var h = 0; h < hits.length && h < 60; h++)
            out.push({ kind: "app", name: hits[h].name, detail: hits[h].exec, app: hits[h],
                       tag: hits[h].source === "steam" ? "Steam" : hits[h].game ? "Game" : "",
                       icon: hits[h].icon || (hits[h].cover ? ui.art(hits[h].cover) : "") });
        if (q.trim())
            out.push({ kind: "command", name: "Run “" + q.trim() + "”", detail: "Use what you typed as the command", tag: "Command" });
        return out;
    }

    function fileRows(q) {
        var out = [];
        var covers = purpose === "cover";
        if (folder !== "/")
            out.push({ kind: "up", name: "..", detail: "Up one folder", tag: "" });
        q = q.toLowerCase();
        for (var i = 0; i < files.length; i++) {
            var f = files[i];
            if (q && f.name.toLowerCase().indexOf(q) < 0)
                continue;
            if (covers && !f.dir && imageTypes.indexOf(f.suffix.toLowerCase()) < 0)
                continue; // only pictures when choosing a cover
            if (covers && !f.dir) {
                out.push({ kind: "image", name: f.name, detail: "", tag: f.suffix.toUpperCase(), path: f.path,
                           icon: "file://" + f.path.split("/").map(encodeURIComponent).join("/") });
                continue;
            }
            out.push({ kind: f.dir ? "dir" : "file", name: f.name + (f.dir ? "/" : ""), detail: "", tag: f.dir ? "" : f.suffix.toUpperCase(), path: f.path });
        }
        if (covers && hasCover && !q) // last, so Enter never lands on it by accident
            out.push({ kind: "clear", name: "Remove the custom cover", detail: "Go back to the drawn box art", tag: "" });
        return out;
    }

    // Start on the most useful row: the first match, not "browse" or ".."
    onRowsChanged: index = rows.length > 1 && (rows[0].kind === "up" || (mode === "apps" && input.text)) ? 1 : 0

    FolderListModel {
        id: dir
        folder: "file://" + sheet.folder.split("/").map(encodeURIComponent).join("/")
        showDirsFirst: true
        showHidden: false
        showDotAndDotDot: false
        sortField: FolderListModel.Name
        onStatusChanged: if (status === FolderListModel.Ready) sheet.readFolder()
        onCountChanged: if (status === FolderListModel.Ready) sheet.readFolder()
    }
    function readFolder() {
        var out = [];
        for (var i = 0; i < dir.count; i++)
            out.push({ name: dir.get(i, "fileName"), path: dir.get(i, "filePath"), dir: dir.isFolder(i), suffix: dir.get(i, "fileSuffix") || "" });
        files = out;
    }

    // ---- turning a choice into a game ----------------------------------------
    function pretty(name) {
        name = String(name).replace(/\.[A-Za-z0-9_]{1,8}$/, "").replace(/[_\-.]+/g, " ").replace(/\s+/g, " ").trim();
        return name.replace(/\b[a-z]/g, function (c) { return c.toUpperCase(); });
    }

    function fromFile(path) {
        var base = path.slice(path.lastIndexOf("/") + 1);
        var where = path.slice(0, path.lastIndexOf("/")) || "/";
        var dot = base.lastIndexOf(".");
        var ext = dot > 0 ? base.slice(dot + 1).toLowerCase() : "";
        var q = Util.shellQuote(path);
        var d = { title: pretty(base), cwd: where, note: "" };
        if (["exe", "msi", "bat"].indexOf(ext) >= 0) {
            d.exec = "wine " + q;
            d.note = "Windows program: runs with Wine. Change the command to use Proton or another runner.";
        } else if (ext === "sh") {
            d.exec = "sh " + q;
        } else if (["", "appimage", "x86_64", "x86", "bin", "run"].indexOf(ext) >= 0) {
            d.exec = q;
            d.note = "Runs the file directly, so it must be marked executable.";
        } else {
            d.exec = "xdg-open " + q;
            d.note = "Opens with your default app for ." + ext + " files. To use a specific emulator, change the command, e.g. pcsx2-qt " + q;
        }
        return d;
    }

    function activate(row) {
        if (!row)
            return;
        if (row.kind === "browse") {
            mode = "files";
            input.text = "";
        } else if (row.kind === "up") {
            folder = folder.slice(0, folder.lastIndexOf("/")) || "/";
            input.text = "";
        } else if (row.kind === "dir") {
            folder = row.path;
            input.text = "";
        } else if (row.kind === "image") {
            coverPicked(row.path);
        } else if (row.kind === "clear") {
            coverPicked("");
        } else {
            if (row.kind === "app")
                draft = { title: row.app.name, exec: String(row.app.exec || "").replace(/%%/g, "\u0000").replace(/\s*%[a-zA-Z]/g, "").replace(/\u0000/g, "%").trim(), icon: row.app.icon || "", cover: row.app.cover || "", logo: row.app.logo || "", group: row.app.group || "",
                          note: row.app.source === "steam" ? "Steam game: starts through the Steam client." : "" };
            else if (row.kind === "command")
                draft = { title: pretty(input.text.trim().split(/\s+/)[0].split("/").pop()), exec: input.text.trim(), note: "" };
            else
                draft = fromFile(row.path);
            backTo = mode;
            primeOn = false;
            mode = "confirm";
            titleIn.text = draft.title;
            execIn.text = draft.exec;
            execIn.cursorPosition = 0;
            groupIn.text = draft.group || "";
            titleIn.forceActiveFocus();
            titleIn.selectAll();
        }
    }

    function finish() {
        var title = titleIn.text.trim(), cmd = execIn.text.trim();
        if (!title || !cmd) {
            (title ? execIn : titleIn).forceActiveFocus();
            return;
        }
        var e = { title: title, exec: cmd };
        if (groupIn.text.trim())
            e.group = groupIn.text.trim();
        if (draft.icon)
            e.icon = draft.icon;
        if (draft.cover)
            e.cover = draft.cover;
        if (draft.logo)
            e.logo = draft.logo;
        if (draft.cwd)
            e.cwd = draft.cwd;
        if (primeOn)
            e.prime = true;
        accepted(e);
    }

    function back() {
        if (mode === "confirm") {
            mode = backTo;
            input.forceActiveFocus();
        } else if (mode === "files" && purpose === "game") {
            mode = "apps";
            input.text = "";
        } else {
            closed();
        }
    }

    Keys.onPressed: e => { // Ctrl+P while checking the details
        if (mode === "confirm" && (e.modifiers & Qt.ControlModifier) && e.key === Qt.Key_P) {
            primeOn = !primeOn;
            e.accepted = true;
        }
    }

    // ---- look ----------------------------------------------------------------
    Rectangle { // dim the shelf behind the sheet
        anchors.fill: parent
        color: Util.alpha(t.colors.panel, 0.9)
        MouseArea { anchors.fill: parent; acceptedButtons: Qt.AllButtons; onClicked: sheet.closed() }
    }

    Rectangle {
        id: card
        anchors.centerIn: parent
        width: Math.min(parent.width - ui.px(80), ui.px(760))
        height: Math.min(parent.height - ui.px(80), ui.px(sheet.mode === "confirm" ? 470 : 580))
        color: Util.mix(t.colors.panel, t.colors.text, 0.04)
        radius: ui.glass ? ui.px(26) : 0
        border { width: 1; color: t.colors.line }
        readonly property real pad: ui.px(24)

        MouseArea { anchors.fill: parent; acceptedButtons: Qt.AllButtons }

        Label {
            id: heading
            ui: sheet.ui
            x: card.pad; y: card.pad
            width: parent.width - card.pad * 2 - esc.width - ui.px(16)
            elide: Text.ElideMiddle
            color: sheet.ui.accentText
            font.capitalization: Font.MixedCase
            text: sheet.purpose === "cover" ? "COVER FOR " + sheet.coverFor.toUpperCase() + "  /  " + sheet.folder.replace(sheet.homeDir, "~")
                : sheet.mode === "files" ? "ADD A GAME  /  " + sheet.folder.replace(sheet.homeDir, "~")
                : sheet.mode === "confirm" ? "ADD A GAME  /  CHECK THE DETAILS" : "ADD A GAME"
        }
        Label {
            id: esc
            ui: sheet.ui
            anchors { right: parent.right; rightMargin: card.pad; verticalCenter: heading.verticalCenter }
            color: t.colors.muted
            text: sheet.mode === "apps" || sheet.purpose === "cover" ? "Esc / Cancel" : "Esc / Back"
            MouseArea { anchors.fill: parent; anchors.margins: -ui.px(8); onClicked: sheet.back() }
        }

        // ---- search / filter line + results ----
        Item {
            anchors { fill: parent; margins: card.pad; topMargin: card.pad + ui.px(34) }
            visible: sheet.mode !== "confirm"

            Rectangle {
                id: field
                width: parent.width; height: ui.px(46)
                radius: ui.rad(height)
                color: "transparent"
                border { width: 1; color: sheet.ui.accentText }
                Text {
                    anchors { left: parent.left; leftMargin: ui.px(14); verticalCenter: parent.verticalCenter }
                    visible: input.text === ""
                    text: sheet.purpose === "cover" ? "Type to filter the pictures in this folder" : sheet.mode === "files" ? "Type to filter this folder" : "Type an app name or a command"
                    color: t.colors.muted
                    font: input.font
                }
                TextInput {
                    id: input
                    anchors { fill: parent; leftMargin: ui.px(14); rightMargin: ui.px(14) }
                    verticalAlignment: TextInput.AlignVCenter
                    clip: true
                    focus: true
                    color: t.colors.text
                    selectionColor: t.colors.accent
                    selectedTextColor: t.colors.text
                    font { family: t.fonts.mono; pixelSize: ui.px(15) }
                    Keys.onPressed: e => {
                        if (e.key === Qt.Key_Down || (e.key === Qt.Key_Tab)) {
                            sheet.index = Math.min(sheet.rows.length - 1, sheet.index + 1);
                        } else if (e.key === Qt.Key_Up || e.key === Qt.Key_Backtab) {
                            sheet.index = Math.max(0, sheet.index - 1);
                        } else if (e.key === Qt.Key_PageDown) {
                            sheet.index = Math.min(sheet.rows.length - 1, sheet.index + 8);
                        } else if (e.key === Qt.Key_PageUp) {
                            sheet.index = Math.max(0, sheet.index - 8);
                        } else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) {
                            sheet.activate(sheet.rows[sheet.index]);
                        } else if (e.key === Qt.Key_Escape) {
                            sheet.back();
                        } else if (e.key === Qt.Key_Backspace && text === "" && sheet.mode === "files") {
                            sheet.activate({ kind: "up" });
                        } else {
                            return;
                        }
                        e.accepted = true;
                    }
                }
            }

            ListView {
                id: list
                anchors { top: field.bottom; topMargin: ui.px(10); left: parent.left; right: parent.right; bottom: tips.top; bottomMargin: ui.px(10) }
                clip: true
                model: sheet.rows
                currentIndex: sheet.index
                highlightMoveDuration: 0
                boundsBehavior: Flickable.StopAtBounds
                delegate: Rectangle {
                    id: row
                    required property var modelData
                    required property int index
                    readonly property bool on: index === sheet.index
                    width: list.width; height: ui.px(42)
                    radius: ui.glass ? ui.px(10) : 0
                    color: on ? Util.alpha(t.colors.accent, 0.32) : rowArea.containsMouse ? Util.alpha(t.colors.text, 0.06) : "transparent"

                    Rectangle { width: ui.px(3); height: parent.height; color: t.colors.accent; visible: row.on }
                    Image {
                        id: glyph
                        x: ui.px(14)
                        anchors.verticalCenter: parent.verticalCenter
                        width: ui.px(22); height: width
                        visible: status === Image.Ready
                        source: row.modelData.icon || ""
                        sourceSize: Qt.size(64, 64)
                        asynchronous: true
                    }
                    Text {
                        id: rowName
                        x: ui.px(glyph.visible ? 46 : 14)
                        anchors.verticalCenter: parent.verticalCenter
                        width: Math.min(implicitWidth, parent.width * 0.55)
                        elide: Text.ElideRight
                        text: row.modelData.name
                        color: row.modelData.kind === "browse" || row.modelData.kind === "command" || row.modelData.kind === "clear" ? sheet.ui.accentText : t.colors.text
                        font { family: t.fonts.label; pixelSize: ui.px(15); weight: Font.Medium }
                    }
                    Text {
                        anchors { left: rowName.right; leftMargin: ui.px(14); right: rowTag.left; rightMargin: ui.px(12); verticalCenter: parent.verticalCenter }
                        elide: Text.ElideRight
                        text: row.modelData.detail || ""
                        color: t.colors.muted
                        font { family: t.fonts.mono; pixelSize: ui.px(12) }
                    }
                    Label {
                        id: rowTag
                        ui: sheet.ui
                        anchors { right: parent.right; rightMargin: ui.px(14); verticalCenter: parent.verticalCenter }
                        size: t.sizes.label - 1
                        color: t.colors.muted
                        text: row.modelData.tag || ""
                    }
                    MouseArea {
                        id: rowArea
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: { sheet.index = row.index; sheet.activate(row.modelData); input.forceActiveFocus(); }
                    }
                }
            }
            Label {
                ui: sheet.ui
                anchors.centerIn: list
                visible: sheet.mode === "files" && sheet.rows.length <= 1
                color: t.colors.muted
                text: input.text ? "Nothing matches" : "Empty folder"
            }

            Label {
                id: tips
                ui: sheet.ui
                anchors.bottom: parent.bottom
                size: t.sizes.label - 1
                color: t.colors.muted
                text: sheet.mode === "files" ? "↑ ↓ Choose    Enter Open    Backspace Up a folder    Esc Back"
                                             : "↑ ↓ Choose    Enter Select    Esc Cancel"
            }
        }

        // ---- confirm ----
        Column {
            anchors { fill: parent; margins: card.pad; topMargin: card.pad + ui.px(40) }
            visible: sheet.mode === "confirm"
            spacing: ui.px(14)

            Repeater {
                model: [{ label: "Title", hint: "" }, { label: "Command", hint: "" }, { label: "Group", hint: "Optional tab, e.g. PC" }]
                Item {
                    required property var modelData
                    required property int index
                    width: parent.width; height: ui.px(46)
                    readonly property TextInput box: [titleIn, execIn, groupIn][index]
                    Label {
                        ui: sheet.ui
                        anchors.verticalCenter: parent.verticalCenter
                        color: t.colors.muted
                        text: modelData.label
                    }
                    Rectangle {
                        x: ui.px(100); width: parent.width - x; height: parent.height
                        radius: ui.rad(height)
                        color: "transparent"
                        border { width: 1; color: parent.box.activeFocus ? sheet.ui.accentText : t.colors.line }
                        Text {
                            anchors { left: parent.left; leftMargin: ui.px(14); verticalCenter: parent.verticalCenter }
                            visible: parent.parent.box.text === ""
                            text: modelData.hint + (index === 2 && sheet.groups.length ? "  (" + sheet.groups.join(", ") + ")" : "")
                            color: t.colors.muted
                            font { family: t.fonts.label; pixelSize: ui.px(14) }
                        }
                        MouseArea { anchors.fill: parent; onClicked: parent.parent.box.forceActiveFocus() }
                    }
                }
            }
            Item { // dedicated-GPU switch
                width: parent.width; height: ui.px(30)
                Rectangle {
                    id: tick
                    x: ui.px(100); width: ui.px(22); height: width
                    anchors.verticalCenter: parent.verticalCenter
                    color: sheet.primeOn ? t.colors.accent : "transparent"
                    border { width: 1; color: sheet.primeOn ? t.colors.accent : t.colors.line }
                    Text {
                        anchors.centerIn: parent
                        visible: sheet.primeOn
                        text: "\u2713"
                        color: Util.ink(t.colors.accent)
                        font.pixelSize: ui.px(15)
                    }
                }
                Text {
                    anchors { left: tick.right; leftMargin: ui.px(12); verticalCenter: parent.verticalCenter }
                    text: "Run on the dedicated GPU (PRIME)"
                    color: t.colors.text
                    font { family: t.fonts.label; pixelSize: ui.px(14) }
                }
                Label {
                    ui: sheet.ui
                    anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                    size: t.sizes.label - 1
                    color: t.colors.muted
                    text: "Ctrl+P"
                }
                MouseArea { anchors.fill: parent; onClicked: sheet.primeOn = !sheet.primeOn }
            }
            Text {
                width: parent.width
                wrapMode: Text.Wrap
                visible: text !== ""
                text: sheet.draft.note || ""
                color: t.colors.muted
                font { family: t.fonts.label; pixelSize: ui.px(13) }
            }
        }
        // The inputs sit over the boxes drawn above (same geometry).
        TextInput {
            id: titleIn
            visible: sheet.mode === "confirm"
            x: card.pad + ui.px(114); y: card.pad + ui.px(40); width: card.width - card.pad * 2 - ui.px(128); height: ui.px(46)
            verticalAlignment: TextInput.AlignVCenter
            clip: true
            color: t.colors.text; selectionColor: t.colors.accent; selectedTextColor: t.colors.text
            font { family: t.fonts.label; pixelSize: ui.px(16); weight: Font.Medium }
            KeyNavigation.tab: execIn; KeyNavigation.down: execIn; KeyNavigation.backtab: groupIn
            Keys.onReturnPressed: sheet.finish()
            Keys.onEnterPressed: sheet.finish()
            Keys.onEscapePressed: sheet.back()
        }
        TextInput {
            id: execIn
            visible: sheet.mode === "confirm"
            x: titleIn.x; y: titleIn.y + ui.px(60); width: titleIn.width; height: titleIn.height
            verticalAlignment: TextInput.AlignVCenter
            clip: true
            color: t.colors.text; selectionColor: t.colors.accent; selectedTextColor: t.colors.text
            font { family: t.fonts.mono; pixelSize: ui.px(14) }
            KeyNavigation.tab: groupIn; KeyNavigation.down: groupIn; KeyNavigation.backtab: titleIn; KeyNavigation.up: titleIn
            Keys.onReturnPressed: sheet.finish()
            Keys.onEnterPressed: sheet.finish()
            Keys.onEscapePressed: sheet.back()
        }
        TextInput {
            id: groupIn
            visible: sheet.mode === "confirm"
            x: titleIn.x; y: titleIn.y + ui.px(120); width: titleIn.width; height: titleIn.height
            verticalAlignment: TextInput.AlignVCenter
            clip: true
            color: t.colors.text; selectionColor: t.colors.accent; selectedTextColor: t.colors.text
            font { family: t.fonts.label; pixelSize: ui.px(16); weight: Font.Medium }
            KeyNavigation.tab: titleIn; KeyNavigation.backtab: execIn; KeyNavigation.up: execIn
            Keys.onReturnPressed: sheet.finish()
            Keys.onEnterPressed: sheet.finish()
            Keys.onEscapePressed: sheet.back()
        }

        Row {
            visible: sheet.mode === "confirm"
            anchors { left: parent.left; right: parent.right; bottom: parent.bottom; margins: card.pad }
            spacing: ui.px(16)
            Rectangle {
                width: addLabel.implicitWidth + ui.px(28); height: ui.px(34)
                radius: ui.rad(height)
                color: t.colors.accent
                Label { id: addLabel; ui: sheet.ui; anchors.centerIn: parent; text: "Enter / Add to shelf"; color: Util.ink(t.colors.accent) }
                MouseArea { anchors.fill: parent; onClicked: sheet.finish() }
            }
            Label {
                ui: sheet.ui
                anchors.verticalCenter: parent.verticalCenter
                size: t.sizes.label - 1
                color: t.colors.muted
                text: "Tab Next field    Esc Back"
            }
        }
    }
}
