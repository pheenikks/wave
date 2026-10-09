#!/usr/bin/env python3
"""Run the Wave UI in a plain Qt window, without Quickshell.

    pip install PySide6
    dev/preview.py                       # interactive, example library
    dev/preview.py --theme neon
    dev/preview.py --shot out.png        # render one frame and exit

Reads config.json / games.json from --dir (default: examples/).
"""
import argparse
import json
import os
import sys
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent


def load(path, fallback):
    try:
        return json.loads(Path(path).read_text())
    except FileNotFoundError:
        return fallback


def desktop_apps():
    """Installed applications, read straight from .desktop files."""
    import configparser
    out, seen = [], set()
    dirs = [Path.home() / ".local/share/applications", Path("/usr/local/share/applications"), Path("/usr/share/applications")]
    for d in dirs:
        for f in sorted(d.glob("*.desktop")):
            cp = configparser.ConfigParser(interpolation=None, strict=False)
            try:
                cp.read(f, encoding="utf-8")
                e = cp["Desktop Entry"]
            except Exception:
                continue
            if f.name in seen or e.get("NoDisplay") == "true" or not e.get("Exec") or not e.get("Name"):
                continue
            seen.add(f.name)
            icon = e.get("Icon", "")
            out.append({"name": e["Name"], "exec": e["Exec"], "comment": e.get("GenericName", e.get("Comment", "")),
                        "icon": "file://" + icon if icon.startswith("/") else "",
                        "game": "Game" in e.get("Categories", "").split(";")})
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--dir", default=str(ROOT / "examples"))
    ap.add_argument("--theme")
    ap.add_argument("--size", default="1920x1080")
    ap.add_argument("--shot", help="write a PNG and exit")
    ap.add_argument("--select", type=int, help="index to select before the shot")
    ap.add_argument("--group")
    ap.add_argument("--query")
    ap.add_argument("--stats", help="stats json file")
    ap.add_argument("--apps", help="json file with a fake application list")
    ap.add_argument("--set", action="append", default=[], help="config override as JSON object")
    args = ap.parse_args()

    if args.shot:
        os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")
        os.environ.setdefault("QT_QUICK_BACKEND", "software")

    from PySide6.QtCore import QTimer, QUrl
    from PySide6.QtGui import QColor, QGuiApplication
    from PySide6.QtQuick import QQuickView

    app = QGuiApplication(sys.argv)
    config = load(Path(args.dir) / "config.json", {})
    for extra in args.set:
        config.update(json.loads(extra))
    if args.theme:
        config["theme"] = args.theme
    games = load(Path(args.dir) / "games.json", [])
    name = config.get("theme", "ocean")
    theme = load(ROOT / "themes" / f"{name}.json", {})
    stats = load(args.stats, {}) if args.stats else {}

    view = QQuickView()
    view.setColor(QColor("#101014"))
    view.setResizeMode(QQuickView.ResizeMode.SizeRootObjectToView)
    w, h = (int(v) for v in args.size.split("x"))
    view.resize(w, h)
    view.setInitialProperties({
        "config": config, "theme": theme, "games": games, "stats": stats,
        "homeDir": str(Path.home()), "baseDir": str(Path(args.dir).resolve()),
        "apps": load(args.apps, []) if args.apps else desktop_apps(),
    })
    view.setSource(QUrl.fromLocalFile(str(ROOT / "ui" / "Launcher.qml")))
    if view.status() != QQuickView.Status.Ready:
        for e in view.errors():
            print(e.toString(), file=sys.stderr)
        return 1
    item = view.rootObject()
    item.closeRequested.connect(app.quit)

    def as_py(v):
        return v.toVariant() if hasattr(v, "toVariant") else v

    def slug(t):
        import re
        return re.sub(r"[^a-z0-9]+", "-", t.lower()).strip("-")

    def add(entry):  # in memory only; the real launcher writes games.json
        games.append(as_py(entry))
        item.setProperty("games", games)
        print("add:", games[-1])

    def remove(gid):
        games[:] = [g for g in games if slug(g.get("id") or g["title"]) != gid]
        item.setProperty("games", games)
        print("remove:", gid)

    def prime(gid):
        for g in games:
            if slug(g.get("id") or g["title"]) == gid:
                g["prime"] = not g.get("prime")
        item.setProperty("games", games)

    def edit(key, value):  # the real launcher writes config.json
        config[key] = as_py(value)
        item.setProperty("config", config)
        if key == "theme":
            item.setProperty("theme", load(ROOT / "themes" / f"{config['theme']}.json", {}))

    item.configEdited.connect(edit)
    def cover(gid, path):
        for g in games:
            if slug(g.get("id") or g["title"]) == gid:
                if path:
                    g["cover"] = path
                else:
                    g.pop("cover", None)
        item.setProperty("games", games)

    item.coverChanged.connect(cover)
    item.primeToggled.connect(prime)
    item.addRequested.connect(add)
    item.removeRequested.connect(remove)
    item.launchRequested.connect(lambda g: print("launch:", g.toVariant() if hasattr(g, "toVariant") else g))
    view.show()
    item.setProperty("active", True)

    if args.shot:
        def pump(seconds):
            end = time.time() + seconds
            while time.time() < end:
                app.processEvents()
                time.sleep(0.01)
        pump(1.6)
        if args.group:
            item.setProperty("group", args.group)
        if args.query is not None:
            item.setProperty("searching", True)
            item.setProperty("query", args.query)
        if args.select is not None:
            from PySide6.QtCore import QMetaObject, Q_ARG
            QMetaObject.invokeMethod(item, "select", Q_ARG("QVariant", args.select))
        pump(1.2)
        view.grabWindow().save(args.shot)
        return 0
    return app.exec()


if __name__ == "__main__":
    sys.exit(main())
