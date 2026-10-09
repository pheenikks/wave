import QtQuick
import "Util.js" as Util

// The underwater backdrop for glass themes: a glow under the surface, shafts
// of light, drifting specks, rising bubbles and dunes along the bottom. All
// drawn from the theme's own colours, so it follows the colour picker.
Item {
    id: scene

    property var ui
    property real level: 0            // y of the water surface
    property bool motion: true
    property bool running: true
    property real radius: 0           // the panel's corner radius, so nothing spills past it

    readonly property string deep: ui.t.colors.panel
    readonly property string light: ui.t.colors.text
    readonly property string glow: ui.t.colors.accent

    // One slow clock moves every bubble. A 20-per-second timer costs a fraction
    // of a per-frame animation, and bubbles this slow look the same.
    property real clock: 0
    Timer {
        interval: 50
        repeat: true
        running: scene.motion && scene.running && scene.visible
        onTriggered: scene.clock += 0.05
    }

    // Small repeatable random generator, so the scene is the same every time.
    function rng(seed) {
        var s = seed >>> 0;
        return function () {
            s = (s + 0x6D2B79F5) >>> 0;
            var t = Math.imul(s ^ (s >>> 15), 1 | s);
            t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
            return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
        };
    }

    Canvas {
        id: paint
        anchors.fill: parent
        property string k: scene.deep + scene.light + scene.glow + scene.level
        onKChanged: requestPaint()
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        onPaint: {
            var c = getContext("2d");
            c.reset();
            var w = width, h = height, lv = scene.level, r = scene.rng(11);
            var i, x, g;
            c.beginPath();
            c.roundedRect(0, 0, w, h, scene.radius, scene.radius);
            c.clip();

            // glow where the sun meets the water
            g = c.createRadialGradient(w * 0.5, lv, 0, w * 0.5, lv, w * 0.46);
            g.addColorStop(0, Util.alpha(scene.glow, 0.34));
            g.addColorStop(0.45, Util.alpha(scene.glow, 0.1));
            g.addColorStop(1, Util.alpha(scene.glow, 0));
            c.fillStyle = g;
            c.fillRect(0, lv, w, h - lv);

            // shafts of light fanning out from a sun above the panel
            var sunX = w * 0.5, sunY = lv - h * 0.75;
            for (i = 0; i < 9; i++) {
                var x0 = w * (0.06 + i * 0.105 + (r() - 0.5) * 0.05);
                var tw = w * (0.012 + r() * 0.034);
                var len = h * (0.42 + r() * 0.42);
                var k0 = (lv + len - sunY) / (lv - sunY);
                g = c.createLinearGradient(0, lv, 0, lv + len);
                g.addColorStop(0, Util.alpha(scene.light, 0.05 + r() * 0.09));
                g.addColorStop(1, Util.alpha(scene.light, 0));
                c.fillStyle = g;
                c.beginPath();
                c.moveTo(x0, lv);
                c.lineTo(x0 + tw, lv);
                c.lineTo(sunX + (x0 + tw - sunX) * k0, lv + len);
                c.lineTo(sunX + (x0 - sunX) * k0, lv + len);
                c.closePath();
                c.fill();
            }

            // specks hanging in the water
            for (i = 0; i < 90; i++) {
                x = r() * w;
                var y = lv + r() * (h - lv);
                c.fillStyle = Util.alpha(scene.light, 0.05 + r() * 0.16);
                c.beginPath();
                c.arc(x, y, 0.6 + r() * 1.5, 0, Math.PI * 2);
                c.fill();
            }

            // dunes: three layers, rising toward the corners like a reef
            var layers = [[0.885, 26, 0.0052, 0.6, 0.16, 0.42], [0.925, 20, 0.0083, 2.1, 0.28, 0.6], [0.962, 14, 0.0121, 4.0, 0.4, 0.8]];
            for (i = 0; i < layers.length; i++) {
                var L = layers[i];
                c.fillStyle = Util.alpha(Util.mix(scene.deep, "#000000", L[4]), L[5]);
                c.beginPath();
                c.moveTo(0, h);
                for (x = 0; x <= w + 6; x += 6) {
                    var edge = Math.pow(Math.abs(x / w - 0.5) * 2, 2.4);
                    var yy = h * L[0] - edge * h * 0.085 * (1.25 - i * 0.3)
                             + Math.sin(x * L[2] + L[3]) * ui.px(L[1]) * 0.5 + Math.sin(x * L[2] * 2.7 + L[3] * 3) * ui.px(L[1]) * 0.22;
                    c.lineTo(x, yy);
                }
                c.lineTo(w, h);
                c.closePath();
                c.fill();
            }

            // deepen the bottom so the footer text stays readable
            g = c.createLinearGradient(0, h * 0.7, 0, h);
            g.addColorStop(0, Util.alpha(Util.mix(scene.deep, "#000000", 0.5), 0));
            g.addColorStop(1, Util.alpha(Util.mix(scene.deep, "#000000", 0.5), 0.22));
            c.fillStyle = g;
            c.fillRect(0, h * 0.7, w, h * 0.3);
        }
    }

    // bubbles drifting up; frozen in place when motion is off
    Repeater {
        model: 16
        Rectangle {
            id: bubble
            required property int index
            readonly property var rnd: scene.rng(index * 97 + 5)
            readonly property real x0: rnd() * scene.width
            readonly property real size: ui.px(5 + rnd() * 15)
            readonly property real phase: rnd()
            readonly property real sway: 1 + rnd() * 2
            readonly property real q: (scene.clock / (22 + index * 1.7) + phase) % 1   // 0 at the bottom, 1 at the surface

            width: size; height: size; radius: size / 2
            x: x0 + Math.sin(q * Math.PI * 2 * sway) * ui.px(12)
            y: scene.height - q * (scene.height - scene.level) - size
            color: Util.alpha(scene.light, 0.05)
            border { width: 1; color: Util.alpha(scene.light, 0.32) }
            opacity: Math.min(1, q * 5, (1 - q) * 6)

            Rectangle { // highlight
                x: parent.width * 0.22; y: parent.height * 0.2
                width: parent.width * 0.22; height: width; radius: width / 2
                color: Util.alpha(scene.light, 0.45)
            }
        }
    }
}
