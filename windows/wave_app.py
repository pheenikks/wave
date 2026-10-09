"""Wave for Windows.

Hosts the same interface as the Linux version (everything in ui/) in an
ordinary Qt window, and does the jobs Quickshell does there: the window, a
global hotkey, reading and saving files, and starting games.

It also runs on Linux and macOS, which is how it gets developed and tested:

    pip install PySide6-Essentials
    python windows/wave_app.py            # start in the tray, Ctrl+Alt+G to open
    python windows/wave_app.py --show     # open straight away
    python windows/wave_app.py --smoke out.png   # render one frame and exit
"""
import json
import os
import re
import subprocess
import sys
import time
from pathlib import Path

WINDOWS = sys.platform == "win32"
APP = Path(getattr(sys, "_MEIPASS", Path(__file__).resolve().parent.parent))   # where ui/, assets/, themes/ live
if WINDOWS:
    DATA = Path(os.environ.get("APPDATA", Path.home())) / "Wave"
else:
    DATA = Path(os.environ.get("XDG_CONFIG_HOME") or Path.home() / ".config") / "wave-desktop"
SERVER_NAME = "wave-launcher-instance"
DEFAULT_HOTKEY = "ctrl+alt+g"   # Win+G belongs to the Xbox Game Bar


def posix(p):
    return str(p).replace("\\", "/")


def load(path, fallback):
    try:
        return json.loads(Path(path).read_text(encoding="utf-8"))
    except (OSError, ValueError):
        return fallback


def save(path, data):
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.with_suffix(path.suffix + ".tmp")
    tmp.write_text(json.dumps(data, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    os.replace(tmp, path)


def slug(s):
    return re.sub(r"[^a-z0-9]+", "-", str(s).lower()).strip("-")


def game_id(g):
    return str(g.get("id") or slug(g.get("title", "")))


# ---- finding things on this machine ---------------------------------------

def steam_roots():
    roots = []
    if WINDOWS:
        try:
            import winreg
            with winreg.OpenKey(winreg.HKEY_CURRENT_USER, r"Software\Valve\Steam") as key:
                roots.append(Path(winreg.QueryValueEx(key, "SteamPath")[0]))
        except OSError:
            pass
        roots += [Path(r"C:\Program Files (x86)\Steam"), Path(r"C:\Program Files\Steam")]
    else:
        home = Path.home()
        roots += [home / ".local/share/Steam", home / ".steam/steam",
                  home / "Library/Application Support/Steam"]
    seen, out = set(), []
    for r in roots:
        try:
            key = r.resolve()
        except OSError:
            continue
        if r.is_dir() and key not in seen:
            seen.add(key)
            out.append(r)
    return out


NOT_GAMES = re.compile(r"^(Proton|Steam Linux Runtime|Steamworks Common|Steam Controller)", re.I)


def steam_games():
    """Installed Steam games, as entries for the add screen."""
    games = {}
    for root in steam_roots():
        libs = [root]
        vdf = root / "steamapps" / "libraryfolders.vdf"
        if vdf.is_file():
            for m in re.findall(r'"path"\s+"([^"]+)"', vdf.read_text(errors="ignore")):
                libs.append(Path(m.replace("\\\\", "\\")))
        cache = root / "appcache" / "librarycache"
        for lib in libs:
            apps = lib / "steamapps"
            if not apps.is_dir():
                continue
            for manifest in apps.glob("appmanifest_*.acf"):
                text = manifest.read_text(errors="ignore")
                appid = re.search(r'"appid"\s+"(\d+)"', text)
                name = re.search(r'"name"\s+"([^"]+)"', text)
                if not appid or not name or NOT_GAMES.match(name.group(1)) or appid.group(1) in games:
                    continue
                aid = appid.group(1)
                cover = ""
                found = sorted(cache.glob(f"{aid}_library_600x900.*")) + sorted((cache / aid).rglob("library_600x900.*"))
                if found:
                    cover = posix(found[0])
                games[aid] = {
                    "name": name.group(1), "exec": f"steam://rungameid/{aid}" if WINDOWS else f"steam steam://rungameid/{aid}",
                    "icon": "", "cover": cover, "logo": "", "comment": "Steam",
                    "game": True, "source": "steam", "group": "Steam",
                }
    return sorted(games.values(), key=lambda g: g["name"].lower())


def start_menu_apps():
    """Programs from the Start Menu (Windows only)."""
    if not WINDOWS:
        return []
    out, seen = [], set()
    bases = [Path(os.environ.get("APPDATA", "")) / "Microsoft/Windows/Start Menu/Programs",
             Path(os.environ.get("PROGRAMDATA", r"C:\ProgramData")) / "Microsoft/Windows/Start Menu/Programs"]
    skip = re.compile(r"uninstall|readme|help|license|website|documentation", re.I)
    for base in bases:
        if not base.is_dir():
            continue
        for link in base.rglob("*.lnk"):
            name = link.stem
            if skip.search(name) or name.lower() in seen:
                continue
            seen.add(name.lower())
            out.append({"name": name, "exec": f'"{posix(link)}"', "icon": "", "comment": link.parent.name
                        if link.parent != base else "", "game": "game" in posix(link.parent).lower()})
    return sorted(out, key=lambda a: a["name"].lower())


def drives():
    if not WINDOWS:
        return []
    import string
    return [f"{d}:/" for d in string.ascii_uppercase if os.path.exists(f"{d}:\\")]


# ---- Windows: global hotkey and start-with-Windows --------------------------

def parse_hotkey(text):
    mods, key = 0, 0
    for part in str(text or DEFAULT_HOTKEY).lower().replace(" ", "").split("+"):
        if part in ("ctrl", "control"):
            mods |= 0x2
        elif part == "alt":
            mods |= 0x1
        elif part == "shift":
            mods |= 0x4
        elif part in ("win", "super", "meta"):
            mods |= 0x8
        elif re.fullmatch(r"f\d{1,2}", part):
            key = 0x70 + int(part[1:]) - 1
        elif len(part) == 1:
            key = ord(part.upper())
        elif part == "space":
            key = 0x20
    return mods, key


RUN_KEY = r"Software\Microsoft\Windows\CurrentVersion\Run"


def autostart_enabled():
    if not WINDOWS:
        return False
    import winreg
    try:
        with winreg.OpenKey(winreg.HKEY_CURRENT_USER, RUN_KEY) as key:
            winreg.QueryValueEx(key, "Wave")
            return True
    except OSError:
        return False


def set_autostart(on):
    if not WINDOWS:
        return
    import winreg
    with winreg.OpenKey(winreg.HKEY_CURRENT_USER, RUN_KEY, 0, winreg.KEY_SET_VALUE) as key:
        if on:
            exe = sys.executable if getattr(sys, "frozen", False) else f'"{sys.executable}" "{Path(__file__).resolve()}"'
            winreg.SetValueEx(key, "Wave", 0, winreg.REG_SZ, exe if exe.startswith('"') else f'"{exe}"')
        else:
            try:
                winreg.DeleteValue(key, "Wave")
            except OSError:
                pass


# ---- the app ----------------------------------------------------------------

def main(argv):
    smoke = argv[argv.index("--smoke") + 1] if "--smoke" in argv else None
    if smoke:
        os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")
        os.environ.setdefault("QT_QUICK_BACKEND", "software")

    from PySide6.QtCore import QAbstractNativeEventFilter, QObject, QTimer, QUrl, Qt
    from PySide6.QtGui import QAction, QColor, QCursor, QGuiApplication, QIcon
    from PySide6.QtNetwork import QLocalServer, QLocalSocket
    from PySide6.QtQuick import QQuickView, QQuickWindow
    from PySide6.QtWidgets import QApplication, QMenu, QSystemTrayIcon

    QQuickWindow.setDefaultAlphaBuffer(True)
    app = QApplication(argv[:1])
    app.setApplicationName("Wave")
    app.setQuitOnLastWindowClosed(False)
    icon = QIcon(str(APP / "assets" / "icon" / "wave-256.png"))
    app.setWindowIcon(icon)

    # One Wave at a time: a second launch just asks the first to open.
    if not smoke:
        probe = QLocalSocket()
        probe.connectToServer(SERVER_NAME)
        if probe.waitForConnected(300):
            probe.write(b"show")
            probe.waitForBytesWritten(300)
            return 0
        QLocalServer.removeServer(SERVER_NAME)

    def variant(v):
        return v.toVariant() if hasattr(v, "toVariant") else v

    class Host(QObject):
        def __init__(self):
            super().__init__()
            self.view = None
            self.config = load(DATA / "config.json", {})
            self.games = load(DATA / "games.json", [])
            self.stats = load(DATA / "stats.json", {})
            self.apps = []
            for folder in ("covers", "themes"):
                (DATA / folder).mkdir(parents=True, exist_ok=True)

        # -- data for the interface --
        def theme(self):
            name = self.config.get("theme", "ocean")
            return load(DATA / "themes" / f"{name}.json", None) or load(APP / "themes" / f"{name}.json", {})

        def push(self, **props):
            if self.view and self.view.rootObject():
                for key, value in props.items():
                    self.view.rootObject().setProperty(key, value)

        # -- window --
        def build(self):
            view = QQuickView()
            view.setTitle("Wave")
            view.setIcon(icon)
            view.setColor(QColor(0, 0, 0, 0))
            view.setFlags(Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint | Qt.Tool)
            view.setResizeMode(QQuickView.ResizeMode.SizeRootObjectToView)
            view.setInitialProperties({
                "config": self.config, "theme": self.theme(), "games": self.games, "stats": self.stats,
                "startId": self.stats.get("selected", ""), "apps": self.apps,
                "homeDir": posix(Path.home()), "baseDir": posix(DATA),
                "platform": "windows" if WINDOWS else "linux", "drives": drives(),
            })
            view.setSource(QUrl.fromLocalFile(str(APP / "ui" / "Launcher.qml")))
            if view.status() != QQuickView.Status.Ready:
                for err in view.errors():
                    print(err.toString(), file=sys.stderr)
                return None
            root = view.rootObject()
            root.closeRequested.connect(self.hide)
            root.launchRequested.connect(lambda g: self.launch(variant(g)))
            root.favoriteToggled.connect(self.toggle_favorite)
            root.selectionChanged.connect(self.select)
            root.addRequested.connect(lambda e: self.add(variant(e)))
            root.removeRequested.connect(self.remove)
            root.coverChanged.connect(self.set_cover)
            root.configEdited.connect(lambda k, v: self.edit(k, variant(v)))
            return view

        def show(self):
            if self.view is None:
                self.apps = steam_games() + start_menu_apps()
                self.view = self.build()
                if self.view is None:
                    return
            screen = QGuiApplication.screenAt(QCursor.pos()) or QGuiApplication.primaryScreen()
            self.view.setScreen(screen)
            self.view.setGeometry(screen.geometry())
            self.view.show()
            self.view.raise_()
            self.view.requestActivate()
            self.view.rootObject().setProperty("active", True)

        def hide(self):
            if self.view is None:
                return
            save(DATA / "stats.json", self.stats)
            view, self.view = self.view, None
            view.hide()
            if self.config.get("preload"):
                view.rootObject().setProperty("active", False)
                self.view = view
            else:
                view.deleteLater()   # hold nothing while hidden

        def toggle(self):
            if self.view is not None and self.view.isVisible():
                self.hide()
            else:
                self.show()

        # -- what the interface asks for --
        def launch(self, g):
            command = str(g.get("exec", ""))
            cwd = g.get("cwd") or None
            if cwd and str(cwd).startswith("~"):
                cwd = str(Path(cwd).expanduser())
            try:
                if WINDOWS:
                    target = command.strip().strip('"')
                    if re.match(r"^[a-z][a-z0-9+.-]*://", target, re.I) or os.path.exists(target):
                        os.startfile(target, cwd=cwd) if cwd and os.path.isdir(cwd) else os.startfile(target)
                    else:
                        subprocess.Popen(command, shell=True, cwd=cwd if cwd and os.path.isdir(cwd) else None,
                                         creationflags=0x00000008 | 0x00000200)  # detached, own process group
                else:
                    subprocess.Popen(["sh", "-c", command], cwd=cwd, start_new_session=True,
                                     stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            except OSError as err:
                print(f"wave: could not start {g.get('title')}: {err}", file=sys.stderr)
                return
            gid = game_id(g)
            plays = dict(self.stats.get("plays", {}))
            last = dict(self.stats.get("last", {}))
            plays[gid] = plays.get(gid, 0) + 1
            last[gid] = int(time.time() * 1000)
            self.stats = {**self.stats, "plays": plays, "last": last, "selected": gid}
            save(DATA / "stats.json", self.stats)
            self.push(stats=self.stats)

        def toggle_favorite(self, gid):
            favs = list(self.stats.get("favorites", []))
            favs.remove(gid) if gid in favs else favs.append(gid)
            self.stats = {**self.stats, "favorites": favs}
            save(DATA / "stats.json", self.stats)
            self.push(stats=self.stats)

        def select(self, gid):
            self.stats["selected"] = gid

        def save_games(self):
            save(DATA / "games.json", self.games)
            self.push(games=self.games)

        def add(self, entry):
            self.games = self.games + [entry]
            self.save_games()

        def remove(self, gid):
            self.games = [g for g in self.games if game_id(g) != gid]
            self.save_games()

        def set_cover(self, gid, path):
            games = []
            for g in self.games:
                if game_id(g) == gid:
                    g = {k: v for k, v in g.items() if k != "cover"}
                    if path:
                        g["cover"] = path
                games.append(g)
            self.games = games
            self.save_games()

        def edit(self, key, value):
            self.config = {**self.config, key: value}
            save(DATA / "config.json", self.config)
            self.push(config=self.config)
            if key == "theme":
                self.push(theme=self.theme())

    host = Host()

    if smoke:
        host.games = load(APP / "examples" / "games.json", [])
        view = host.build()
        if view is None:
            return 1
        view.resize(1600, 900)
        view.show()
        view.rootObject().setProperty("active", True)
        end = time.time() + 2.5
        while time.time() < end:
            app.processEvents()
            time.sleep(0.01)
        ok = view.grabWindow().save(smoke)
        print("smoke frame written" if ok else "could not write frame")
        return 0 if ok else 1

    server = QLocalServer()
    server.listen(SERVER_NAME)
    server.newConnection.connect(lambda: (server.nextPendingConnection().deleteLater(), host.show()))

    # tray icon: the way to find Wave when it is hidden
    tray = QSystemTrayIcon(icon)
    menu = QMenu()
    hotkey_text = str(host.config.get("hotkey") or DEFAULT_HOTKEY)
    open_action = QAction(f"Open Wave\t{hotkey_text.title()}", menu)
    open_action.triggered.connect(host.show)
    menu.addAction(open_action)
    if WINDOWS:
        auto = QAction("Start with Windows", menu, checkable=True)
        auto.setChecked(autostart_enabled())
        auto.toggled.connect(set_autostart)
        menu.addAction(auto)
    menu.addSeparator()
    quit_action = QAction("Quit", menu)
    quit_action.triggered.connect(app.quit)
    menu.addAction(quit_action)
    tray.setContextMenu(menu)
    tray.setToolTip("Wave")
    tray.activated.connect(lambda reason: host.toggle() if reason == QSystemTrayIcon.ActivationReason.Trigger else None)
    tray.show()

    if WINDOWS:
        import ctypes
        from ctypes import wintypes

        class HotkeyFilter(QAbstractNativeEventFilter):
            def nativeEventFilter(self, event_type, message):
                if bytes(event_type) == b"windows_generic_MSG":
                    msg = wintypes.MSG.from_address(int(message))
                    if msg.message == 0x0312:   # WM_HOTKEY
                        host.toggle()
                        return True, 0
                return False, 0

        mods, key = parse_hotkey(hotkey_text)
        if key and ctypes.windll.user32.RegisterHotKey(None, 1, mods | 0x4000, key):
            hotkey_filter = HotkeyFilter()
            app.installNativeEventFilter(hotkey_filter)
            app.aboutToQuit.connect(lambda: ctypes.windll.user32.UnregisterHotKey(None, 1))
        else:
            tray.showMessage("Wave", f"Could not register {hotkey_text}; another program uses it. "
                                     "Open Wave from this tray icon, or set \"hotkey\" in config.json.")

    first_run = not (DATA / "config.json").exists()
    if first_run:
        save(DATA / "config.json", {**host.config, "hotkey": hotkey_text})
        if not (DATA / "games.json").exists():
            save(DATA / "games.json", [])
    if "--show" in argv or first_run:
        QTimer.singleShot(0, host.show)
    return app.exec()


if __name__ == "__main__":
    sys.exit(main(sys.argv))
