import QtQuick 2.15
import QtQuick.Window 2.15

Item {
    id: root
    width: 1920
    height: 1080

    property int waveCount: 6
    property var waveColors: ["#00d1ff","#66e3ff","#ff4c00","#8aff00","#ff00ff","#ffff00"]
    property real maxAmplitude: 180
    property real minAmplitude: 20
    property real maxWavelength: 400
    property real minWavelength: 100
    property real speed: 0.5  // radians per frame

    property var waves: []

    function hexToRgba(hex, alpha) {
        var r = parseInt(hex.substr(1,2),16);
        var g = parseInt(hex.substr(3,2),16);
        var b = parseInt(hex.substr(5,2),16);
        return "rgba("+r+","+g+","+b+","+alpha+")";
    }

    Canvas {
        id: canvas
        anchors.fill: parent
        antialiasing: true

        onPaint: {
            var ctx = getContext("2d");
            ctx.reset();
            ctx.fillStyle = "black";
            ctx.fillRect(0,0,width,height);

            // Draw filled areas between consecutive waves
            for (var i=0; i<waves.length-1; i++){
                var w1 = waves[i];
                var w2 = waves[i+1];

                ctx.fillStyle = hexToRgba(w1.color, w1.opacity);

                ctx.beginPath();
                // Top wave
                for (var x=0; x<=width; x+=4){
                    var y1 = height/2 + w1.amplitude * Math.sin((x / w1.wavelength) + w1.phase);
                    ctx.lineTo(x,y1);
                }
                // Bottom wave
                for (var x=width; x>=0; x-=4){
                    var y2 = height/2 + w2.amplitude * Math.sin((x / w2.wavelength) + w2.phase);
                    ctx.lineTo(x,y2);
                }
                ctx.closePath();
                ctx.fill();
            }
        }
    }

    Component.onCompleted: {
        for (var i=0;i<waveCount;i++){
            waves.push({
                amplitude: Math.random()*(maxAmplitude-minAmplitude)+minAmplitude,
                       wavelength: Math.random()*(maxWavelength-minWavelength)+minWavelength,
                       phase: Math.random()*Math.PI*2,
                       color: waveColors[i % waveColors.length],
                       opacity: Math.random()*0.45 + 0.05   // fixed opacity between 0.05–0.5
            });
        }
    }

    Timer {
        interval: 33 // ~30 FPS
        repeat: true
        running: true
        onTriggered: {
            for (var i=0;i<waves.length;i++){
                waves[i].phase += speed * 0.033;
                if (waves[i].phase > Math.PI*2) waves[i].phase -= Math.PI*2;
            }
            canvas.requestPaint();
        }
    }
}
