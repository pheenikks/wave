.pragma library

// Shared helpers for Wave. Pure JavaScript, no Quickshell dependencies,
// so the UI can also run in a plain Qt window (see dev/preview.py).

function defaultConfig() {
    return {
        theme: "ocean",
        palette: {},            // { "primary": "#6203fc", "base": "#000000" } recolours any theme
        title: "WAVE",
        tagline: "{count} TITLES / {from} — {to}",
        monitor: "",            // "" = focused monitor (Hyprland) or compositor default
        sort: "manual",         // manual | title | year | recent | plays
        startOn: "last",        // last | first
        wrap: true,
        closeOnLaunch: true,
        launchPrefix: "",       // e.g. "gamemoderun"
        gamemode: false,        // start games through gamemoderun (Feral GameMode)
        steamQuiet: true,       // start Steam games without bringing up Steam's windows
        preload: false,         // keep the interface loaded while hidden: instant open, more idle memory
        quitOnLaunch: false,    // exit Wave completely while a game runs; the keybind brings it back
        primeAll: false,        // run every game on the dedicated GPU
        primeCommand: "",       // "" = NVIDIA offload variables; or "prime-run", "DRI_PRIME=1"
        scale: 1.0,
        shelf: {
            height: 400,        // px before scale; shrinks to fit small screens
            spineWidth: 56,
            gap: 16,
            coverAspect: 0.64,  // cover width / height
            spines: "auto"      // auto | generated | cover
        },
        animation: { speed: 1.0, intro: true },
        features: {             // switches shown in the settings panel
            dock: true,         // the side panel
            dockLabels: true,
            hints: false,       // key hints in the footer
            hero: true,         // big title behind the header (themes that have one)
            scene: true,        // drawn backdrop (light shafts, dunes) in themes that have one
            motion: true,       // bubbles drifting in that backdrop
            grain: true,
            wear: true
        },
        groups: {},             // "PS2": { "name": "PlayStation 2", "color": "#2f4bd8" }
        groupOrder: [],
        overrides: {}           // partial theme, merged over the chosen theme
    };
}

// A whole colour scheme from two colours: `primary` is the brand colour,
// `base` the background it is mixed into. `glass` builds the brighter,
// gradient version used by themes like Ocean.
function paletteColors(primary, base, glass) {
    primary = primary || "#6203fc";
    base = base || "#000000";
    var lightBase = luminance(base) > 0.5;
    var far = lightBase ? "#000000" : "#ffffff";   // the opposite end from the base
    if (glass) {
        var top = mix(base, primary, 0.85), bottom = mix(base, primary, 0.18);
        var mid = mix(top, bottom, 0.5);
        return {
            backdrop: mix(base, lightBase ? "#ffffff" : "#000000", 0.4),
            backdropOpacity: 0.9,
            panelTop: top,
            panel: bottom,
            panelBorder: alpha(far, 0.45),
            text: far,
            muted: mix(far, mid, 0.32),
            line: mix(mid, far, 0.42),
            accent: mix(primary, far, 0.55),
            tapes: [primary, mix(primary, "#000000", 0.55), mix(primary, "#ffffff", 0.45),
                    mix(base, primary, 0.35), mix(primary, "#ffffff", 0.86), complement(primary)],
            paper: mix("#ffffff", primary, 0.07),
            cassette: mix(base, "#000000", 0.35)
        };
    }
    var panel = mix(base, primary, 0.11);
    var text = mix(far, primary, 0.06);
    return {
        backdrop: base,
        backdropOpacity: 0.86,
        panelTop: "",
        panel: panel,
        panelBorder: mix(panel, primary, 0.4),
        text: text,
        muted: mix(text, panel, 0.52),
        line: mix(panel, primary, 0.5),
        accent: primary,
        tapes: [primary, mix(primary, "#000000", 0.5), mix(primary, "#ffffff", 0.32),
                mix(base, primary, 0.2), mix(primary, "#ffffff", 0.62), mix(primary, "#000000", 0.72)],
        paper: mix("#ffffff", primary, 0.1),
        cassette: mix(base, primary, 0.05)
    };
}

// The neutral starting point every theme file is merged over.
function baseTheme() {
    var colors = paletteColors("#6203fc", "#000000", false);
    colors.dock = "#000000";      // the side panel
    colors.dockText = "#ffffff";
    return {
        name: "Wave",
        colors: colors,
        fonts: {
            title: "Instrument Serif",
            titleWeight: 400,
            label: "Space Grotesk",
            mono: "Space Mono",
            hero: "Archivo Black",
            tapes: ["Anton", "Bebas Neue", "DM Serif Display", "Archivo Black",
                    "Caveat Brush", "Instrument Serif"]
        },
        sizes: { title: 38, label: 11, panelMargin: 0.085, panelRadius: 0 },
        style: {
            glass: false,   // gradient panel, frosted cards, palette built the bright way
            radius: 0,      // corner radius of buttons and tabs (0 = square)
            hero: false,    // big title across the top
            scene: false    // underwater backdrop
        },
        effects: { grain: 0.07, wear: 0.4, scanlines: 0.0, vignette: 0.55, gloss: 0.5 }
    };
}
function defaultTheme() { return baseTheme(); }

// The default look: deep-water blues, glass cards, rounded controls.
function oceanTheme() {
    return merge(baseTheme(), {
        name: "Ocean",
        colors: paletteColors("#2f80d8", "#041a40", true),
        fonts: { title: "Montserrat", titleWeight: 600, label: "Montserrat", hero: "Montserrat",
                 tapes: ["Anton", "Bebas Neue", "Archivo Black", "DM Serif Display", "Caveat Brush"] },
        sizes: { title: 32, label: 11, panelMargin: 0.07, panelRadius: 30 },
        style: { glass: true, radius: 999, hero: true, scene: true },
        effects: { grain: 0.03, wear: 0.28, scanlines: 0.0, vignette: 0.22, gloss: 0.55 }
    });
}

var builtinThemes = ["ocean", "wave", "midnight", "paper", "neon", "phosphor", "rental"];

// Theme file, then the config's palette (if any), then explicit overrides,
// then the feature switches.
function resolveTheme(theme, cfg) {
    var src = theme && theme.colors ? theme : (cfg.theme === "ocean" ? oceanTheme() : {});
    var t = merge(baseTheme(), src);
    var pal = cfg.palette || {};
    if (pal.primary || pal.base) {
        t = merge(t, { colors: paletteColors(pal.primary || t.colors.accent, pal.base || t.colors.backdrop, t.style.glass) });
        if (luminance(t.colors.panel) > 0.5) // dark corners look dirty on a light panel
            t = merge(t, { effects: { vignette: Math.min(t.effects.vignette, 0.12) } });
    }
    t = merge(t, cfg.overrides);
    var f = cfg.features || {};
    if (f.grain === false) t.effects.grain = 0;
    if (f.wear === false) t.effects.wear = 0;
    if (f.hero === false) t.style.hero = false;
    if (f.scene === false) t.style.scene = false;
    return t;
}

function isObject(v) {
    return v !== null && typeof v === "object" && !Array.isArray(v);
}

// Deep merge: values in `over` win, arrays are replaced whole.
function merge(base, over) {
    var out = {};
    var k;
    for (k in base)
        out[k] = base[k];
    if (!isObject(over))
        return out;
    for (k in over) {
        if (isObject(over[k]) && isObject(out[k]))
            out[k] = merge(out[k], over[k]);
        else if (over[k] !== undefined && over[k] !== null)
            out[k] = over[k];
    }
    return out;
}

function hash(s) {
    s = String(s || "");
    var h = 2166136261;
    for (var i = 0; i < s.length; i++) {
        h ^= s.charCodeAt(i);
        h = (h * 16777619) >>> 0;
    }
    return h & 0x7fffffff; // keep it positive and int-sized for QML
}

function slug(s) {
    return String(s || "").toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/^-+|-+$/g, "");
}

function gameId(g) {
    return g ? String(g.id || slug(g.title)) : "";
}

// ---- colour ------------------------------------------------------------

function rgb(hex) {
    var h = String(hex || "#000000").replace("#", "");
    if (h.length === 3)
        h = h[0] + h[0] + h[1] + h[1] + h[2] + h[2];
    if (h.length === 8)
        h = h.slice(2); // #aarrggbb
    var n = parseInt(h, 16);
    if (isNaN(n))
        n = 0;
    return [(n >> 16) & 255, (n >> 8) & 255, n & 255];
}

function hex(c) {
    var s = "#";
    for (var i = 0; i < 3; i++) {
        var v = Math.max(0, Math.min(255, Math.round(c[i]))).toString(16);
        s += v.length < 2 ? "0" + v : v;
    }
    return s;
}

function mix(a, b, t) {
    var x = rgb(a), y = rgb(b);
    return hex([x[0] + (y[0] - x[0]) * t, x[1] + (y[1] - x[1]) * t, x[2] + (y[2] - x[2]) * t]);
}

function hsl(h, sat, l) {
    h = ((h % 360) + 360) % 360;
    var c = (1 - Math.abs(2 * l - 1)) * sat, x = c * (1 - Math.abs((h / 60) % 2 - 1)), m = l - c / 2;
    var v = h < 60 ? [c, x, 0] : h < 120 ? [x, c, 0] : h < 180 ? [0, c, x] : h < 240 ? [0, x, c] : h < 300 ? [x, 0, c] : [c, 0, x];
    return hex([(v[0] + m) * 255, (v[1] + m) * 255, (v[2] + m) * 255]);
}

function toHsl(c) {
    var v = rgb(c), r = v[0] / 255, g = v[1] / 255, b = v[2] / 255;
    var mx = Math.max(r, g, b), mn = Math.min(r, g, b), d = mx - mn, l = (mx + mn) / 2, h = 0;
    if (d) {
        h = mx === r ? ((g - b) / d) % 6 : mx === g ? (b - r) / d + 2 : (r - g) / d + 4;
        h *= 60;
    }
    return [(h + 360) % 360, d ? d / (1 - Math.abs(2 * l - 1)) : 0, l];
}

// The opposite hue, kept vivid: one warm tape on a cool shelf (or the reverse).
function complement(c) {
    var v = toHsl(c);
    return hsl(v[0] + 180, Math.max(0.75, v[1]), 0.58);
}

function luminance(c) {
    var v = rgb(c);
    return (0.2126 * v[0] + 0.7152 * v[1] + 0.0722 * v[2]) / 255;
}

// Readable ink for text sitting on `bg`.
function ink(bg, light, dark) {
    return luminance(bg) > 0.52 ? (dark || "#141414") : (light || "#f4f1ea");
}

function contrast(a, b) {
    function l(c) {
        var v = rgb(c).map(function (x) { x /= 255; return x <= 0.03928 ? x / 12.92 : Math.pow((x + 0.055) / 1.055, 2.4); });
        return 0.2126 * v[0] + 0.7152 * v[1] + 0.0722 * v[2];
    }
    var x = l(a), y = l(b);
    return (Math.max(x, y) + 0.05) / (Math.min(x, y) + 0.05);
}

// `c` nudged toward `toward` until it is readable as small text on `bg`.
function readable(c, bg, toward) {
    var out = c;
    for (var i = 1; i <= 8 && contrast(out, bg) < 4.2; i++)
        out = mix(c, toward, i * 0.1);
    return out;
}

function alpha(c, a) {
    var v = Math.max(0, Math.min(255, Math.round(a * 255))).toString(16);
    return "#" + (v.length < 2 ? "0" + v : v) + hex(rgb(c)).slice(1);
}

// ---- paths -------------------------------------------------------------

function resolvePath(p, home, base) {
    if (!p)
        return "";
    p = String(p);
    if (/^[a-z]+:\/\//.test(p))
        return p;
    if (p.indexOf("~/") === 0)
        p = home + p.slice(1);
    if (!isAbsolute(p))
        p = base + "/" + p;
    return fileUrl(p);
}

function isAbsolute(p) {
    return p.charAt(0) === "/" || /^[A-Za-z]:[\\/]/.test(p);
}

// file:// URL for a path on either Linux (/home/x) or Windows (C:/Users/x).
function fileUrl(p) {
    p = String(p).replace(/\\/g, "/");
    var enc = p.split("/").map(encodeURIComponent).join("/").replace(/^([A-Za-z])%3A/, "$1:");
    return (p.charAt(0) === "/" ? "file://" : "file:///") + enc;
}

// What goes in front of a command to run it on the dedicated GPU. The default
// is exactly what the prime-run script sets, so it works without that script.
function primePrefix(custom) {
    return custom || "env __NV_PRIME_RENDER_OFFLOAD=1 __GLX_VENDOR_LIBRARY_NAME=nvidia __VK_LAYER_NV_optimus=NVIDIA_only";
}

// The command Wave actually runs for a game, given the config.
function launchCommand(g, cfg, home) {
    var cmd = String(g.exec);
    var steam = /^steam\s+steam:\/\/rungameid\/(\d{1,9})\s*$/.exec(cmd);
    if (steam) {
        // Steam owns the game process, so GPU and GameMode wrappers here would
        // only wrap the Steam client; those belong in the game's launch options.
        if (cfg.steamQuiet !== false)
            cmd = "steam -silent -nochatui -nofriendsui -applaunch " + steam[1];
    } else {
        if (g.prime || cfg.primeAll)
            cmd = primePrefix(cfg.primeCommand) + " " + cmd;
        if (cfg.gamemode)
            cmd = "gamemoderun " + cmd;
        if (cfg.launchPrefix)
            cmd = cfg.launchPrefix + " " + cmd;
    }
    if (g.cwd) {
        var dir = String(g.cwd).indexOf("~/") === 0 ? home + String(g.cwd).slice(1) : String(g.cwd);
        cmd = "cd " + shellQuote(dir) + " && " + cmd;
    }
    return cmd;
}

function shellQuote(s) {
    return "'" + String(s).replace(/'/g, "'\\''") + "'";
}

// ---- library views -----------------------------------------------------

function groupsOf(games, order) {
    var out = [];
    var i;
    order = order || [];
    for (i = 0; i < order.length; i++)
        out.push(String(order[i]));
    var seen = [];
    for (i = 0; i < games.length; i++) {
        var g = games[i].group;
        if (g && seen.indexOf(g) < 0)
            seen.push(g);
    }
    // drop ordered groups that have no games, append unordered ones
    out = out.filter(function (g) { return seen.indexOf(g) >= 0; });
    for (i = 0; i < seen.length; i++)
        if (out.indexOf(seen[i]) < 0)
            out.push(seen[i]);
    return out;
}

function matches(g, q) {
    if (!q)
        return true;
    var hay = [g.title, g.subtitle, g.group, g.year, (g.tags || []).join(" ")].join(" ").toLowerCase();
    var words = q.toLowerCase().split(/\s+/);
    for (var i = 0; i < words.length; i++)
        if (words[i] && hay.indexOf(words[i]) < 0)
            return false;
    return true;
}

function view(games, opts) {
    var stats = opts.stats || {};
    var favs = stats.favorites || [];
    var plays = stats.plays || {};
    var last = stats.last || {};
    var out = [];
    for (var i = 0; i < games.length; i++) {
        var g = games[i];
        if (!g || !g.title || g.hidden)
            continue;
        if (opts.group === "★") {
            if (favs.indexOf(gameId(g)) < 0)
                continue;
        } else if (opts.group && opts.group !== "ALL" && g.group !== opts.group) {
            continue;
        }
        if (!matches(g, opts.query))
            continue;
        out.push(g);
    }
    var by = {
        title: function (a, b) { return String(a.title).localeCompare(String(b.title)); },
        year: function (a, b) { return (a.year || 9999) - (b.year || 9999) || String(a.title).localeCompare(String(b.title)); },
        recent: function (a, b) { return (last[gameId(b)] || 0) - (last[gameId(a)] || 0); },
        plays: function (a, b) { return (plays[gameId(b)] || 0) - (plays[gameId(a)] || 0); }
    }[opts.sort];
    if (by)
        out.sort(by); // Array.prototype.sort is stable, so ties keep file order
    return out;
}

function yearRange(games) {
    var lo = 0, hi = 0;
    for (var i = 0; i < games.length; i++) {
        var y = parseInt(games[i].year);
        if (!y)
            continue;
        if (!lo || y < lo) lo = y;
        if (!hi || y > hi) hi = y;
    }
    return [lo, hi];
}

function ago(ts, now) {
    if (!ts)
        return "";
    var s = Math.max(0, (now - ts) / 1000);
    if (s < 90) return "JUST NOW";
    if (s < 3600) return Math.round(s / 60) + " MIN AGO";
    if (s < 86400 * 1.5) return Math.round(s / 3600) + " H AGO";
    if (s < 86400 * 45) return Math.round(s / 86400) + " DAYS AGO";
    if (s < 86400 * 540) return Math.round(s / (86400 * 30)) + " MONTHS AGO";
    return Math.round(s / (86400 * 365)) + " YEARS AGO";
}
