import QtQuick

// Small line icons, drawn rather than shipped as files so they take any
// colour and size. Designed on a 24-unit grid.
Canvas {
    id: icon
    property string name: ""
    property string color: "#ffffff"
    property bool filled: false
    property real stroke: 1.9

    width: 24; height: 24
    onNameChanged: requestPaint()
    onColorChanged: requestPaint()
    onFilledChanged: requestPaint()
    onWidthChanged: requestPaint()

    onPaint: {
        var c = getContext("2d");
        c.reset();
        c.scale(width / 24, height / 24);
        c.lineWidth = stroke;
        c.lineCap = "round";
        c.lineJoin = "round";
        c.strokeStyle = color;
        c.fillStyle = color;
        function line(a, b, x, y) { c.beginPath(); c.moveTo(a, b); c.lineTo(x, y); c.stroke(); }
        var i, a;
        switch (name) {
        case "plus":
            line(12, 5, 12, 19); line(5, 12, 19, 12);
            break;
        case "search":
            c.beginPath(); c.arc(10.5, 10.5, 6, 0, Math.PI * 2); c.stroke();
            line(15, 15, 20, 20);
            break;
        case "sort":
            line(4, 7, 20, 7); line(4, 12, 15, 12); line(4, 17, 10, 17);
            break;
        case "star":
            c.beginPath();
            for (i = 0; i < 10; i++) {
                a = -Math.PI / 2 + i * Math.PI / 5;
                var r = i % 2 ? 4 : 9;
                if (i) c.lineTo(12 + Math.cos(a) * r, 12.6 + Math.sin(a) * r);
                else c.moveTo(12 + Math.cos(a) * r, 12.6 + Math.sin(a) * r);
            }
            c.closePath();
            if (filled) c.fill();
            c.stroke();
            break;
        case "gpu":
            c.strokeRect(6.5, 6.5, 11, 11);
            if (filled) c.fillRect(10, 10, 4, 4); else c.strokeRect(10, 10, 4, 4);
            for (i = 0; i < 3; i++) {
                var p = 8.5 + i * 3.5;
                line(p, 3.5, p, 6.5); line(p, 17.5, p, 20.5);
                line(3.5, p, 6.5, p); line(17.5, p, 20.5, p);
            }
            break;
        case "trash":
            line(5, 7, 19, 7);
            c.beginPath(); c.moveTo(10, 7); c.lineTo(10, 4.5); c.lineTo(14, 4.5); c.lineTo(14, 7); c.stroke();
            c.beginPath(); c.moveTo(7, 7); c.lineTo(8, 20); c.lineTo(16, 20); c.lineTo(17, 7); c.stroke();
            line(10.5, 10.5, 10.8, 16.5); line(13.5, 10.5, 13.2, 16.5);
            break;
        case "drop":
            c.beginPath();
            c.moveTo(12, 3);
            c.bezierCurveTo(12, 3, 5, 10.5, 5, 15);
            c.bezierCurveTo(5, 19, 8, 21.5, 12, 21.5);
            c.bezierCurveTo(16, 21.5, 19, 19, 19, 15);
            c.bezierCurveTo(19, 10.5, 12, 3, 12, 3);
            c.closePath();
            c.stroke();
            c.beginPath(); c.arc(12, 15, 3.6, Math.PI * 0.15, Math.PI * 0.6); c.stroke();
            break;
        case "gear":
            c.beginPath(); c.arc(12, 12, 6.2, 0, Math.PI * 2); c.stroke();
            c.beginPath(); c.arc(12, 12, 2.4, 0, Math.PI * 2); c.stroke();
            c.lineWidth = stroke * 1.5;
            for (i = 0; i < 8; i++) { // teeth
                a = i * Math.PI / 4;
                line(12 + Math.cos(a) * 7.6, 12 + Math.sin(a) * 7.6, 12 + Math.cos(a) * 9.6, 12 + Math.sin(a) * 9.6);
            }
            break;
        case "left":
            c.beginPath(); c.moveTo(14.5, 6); c.lineTo(8.5, 12); c.lineTo(14.5, 18); c.stroke();
            break;
        case "right":
            c.beginPath(); c.moveTo(9.5, 6); c.lineTo(15.5, 12); c.lineTo(9.5, 18); c.stroke();
            break;
        case "image":
            c.strokeRect(4, 5.5, 16, 13);
            c.beginPath(); c.arc(9, 10, 1.6, 0, Math.PI * 2); c.stroke();
            c.beginPath(); c.moveTo(4.5, 17); c.lineTo(10, 12.5); c.lineTo(13, 15); c.lineTo(16, 12); c.lineTo(19.5, 15.5); c.stroke();
            break;
        case "check":
            c.beginPath(); c.moveTo(5.5, 12.5); c.lineTo(10, 17); c.lineTo(18.5, 7.5); c.stroke();
            break;
        }
    }
}
