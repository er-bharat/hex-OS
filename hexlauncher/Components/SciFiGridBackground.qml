import QtQuick 2.15
import QtQuick.Window 2.15

Item {
    id: root
    property bool closing: false

    // Mouse offsets
    property real mouseXOffset: 0
    property real mouseYOffset: 0

    // Background and line properties
    property color backgroundColor: "black"
    property real lineOpacity: 0.35
    property real lineThickness: 3
    property int verticalCount: 85
    property int horizontalCount: 65
    property real minSpeed: 100
    property real maxSpeed: 200
    property real minLength: 50
    property real maxLength: 250

    // Scanline properties
    property bool scanlineEnabled: true
    property real scanlineWidth: appModel.borderWidth
    property real scanlineSpeed: 300
    property color scanlineColor: appModel.hoveredColor

    Rectangle {
        id: backgroundRect
        anchors.fill: parent
        color: backgroundColor
        opacity: 1

        // Behavior on opacity { NumberAnimation { duration: appModel.animationDuration; easing.type: Easing.InOutQuad } }
    }


    // Weighted color palette
    property var colors: [
        { c: appModel.borderColor, w: 70 },
        { c: appModel.fillColor, w: 20 },
        { c: appModel.hoveredColor, w: 7 },
        { c: appModel.borderHoveredColor, w: 2 },
        { c: "gold", w: 1 }
    ]

    function weightedColor() {
        var total = 0
        for (var i=0; i<colors.length; i++) total += colors[i].w
            var rnd = Math.random() * total
            for (i=0; i<colors.length; i++) {
                if (rnd < colors[i].w) return colors[i].c
                    rnd -= colors[i].w
            }
            return colors[0].c
    }

    // Close animation
    function closeAnimation() {
        closing = true

        // Fade and shrink vertical lines
        for (var i = 0; i < verticalRepeater.count; i++) {
            var rect = verticalRepeater.itemAt(i)
            rect.width = 0
            rect.height = 0
            rect.opacity = 0
        }

        // Fade and shrink horizontal lines
        for (var i = 0; i < horizontalRepeater.count; i++) {
            var rect = horizontalRepeater.itemAt(i)
            rect.width = 0
            rect.height = 0
            rect.opacity = 0
        }

        // Fade out scanlines
        hScanline.opacity = 0
        vScanline.opacity = 0

        // Fade out background
        // backgroundRect.opacity = 0
    }

    // Vertical lines
    Repeater {
        id: verticalRepeater
        model: verticalCount
        Rectangle {
            width: lineThickness
            height: Math.random() * (maxLength - minLength) + minLength
            color: weightedColor()
            opacity: Math.random() * 0.9 + 0.1
            x: root.width / 2
            y: Math.random() * root.height

            property real speed: (Math.random() * (maxSpeed - minSpeed) + minSpeed)
            property real direction: (Math.random() < 0.5 ? 1 : -1)
            property bool verticalMotion: Math.random() < 0.75
            property real verticalSpeed: verticalMotion ? speed * 0.3 : 0
            property real verticalDirection: verticalMotion ? (Math.random() < 0.5 ? 1 : -1) : 0

            Behavior on width { NumberAnimation { duration: appModel.animationDuration; easing.type: Easing.InOutQuad } }
            Behavior on height { NumberAnimation { duration: appModel.animationDuration; easing.type: Easing.InOutQuad } }
            Behavior on opacity { NumberAnimation { from:0.1; to:1.0; duration:1000; loops:Animation.Infinite; easing.type: Easing.InOutQuad } }

            Timer {
                interval: 16
                repeat: true
                running: true
                onTriggered: {
                    if (!root.closing) {
                        x += speed * 0.016 * direction + mouseXOffset * 1.2
                        y += verticalSpeed * 0.016 * verticalDirection
                        if (Math.abs(x - root.width/2) > root.width/2) {
                            x = root.width/2
                            direction = (Math.random() < 0.5 ? 1 : -1)
                            speed = (Math.random() * (maxSpeed - minSpeed) + minSpeed)
                            color = weightedColor()
                        }
                        if (y < 0) { y = 0; verticalDirection *= -1 }
                        if (y > root.height - height) { y = root.height - height; verticalDirection *= -1 }
                    }
                }
            }
        }
    }

    // Horizontal lines
    Repeater {
        id: horizontalRepeater
        model: horizontalCount
        Rectangle {
            height: lineThickness
            width: Math.random() * (maxLength - minLength) + minLength
            color: weightedColor()
            opacity: Math.random() * 0.9 + 0.1
            y: root.height / 2
            x: Math.random() * root.width

            property real speed: (Math.random() * (maxSpeed - minSpeed) + minSpeed)
            property real direction: (Math.random() < 0.5 ? 1 : -1)
            property bool horizontalMotion: Math.random() < 0.75
            property real horizontalSpeed: horizontalMotion ? speed * 0.3 : 0
            property real horizontalDirection: horizontalMotion ? (Math.random() < 0.5 ? 1 : -1) : 0

            Behavior on width { NumberAnimation { duration: appModel.animationDuration; easing.type: Easing.InOutQuad } }
            Behavior on height { NumberAnimation { duration: appModel.animationDuration; easing.type: Easing.InOutQuad } }
            Behavior on opacity { NumberAnimation { from:0.1; to:1.0; duration:appModel.animationDuration; loops:Animation.Infinite; easing.type: Easing.InOutQuad } }

            Timer {
                interval: 16
                repeat: true
                running: true
                onTriggered: {
                    if (!root.closing) {
                        y += speed * 0.016 * direction + mouseYOffset * 1.2
                        x += horizontalSpeed * 0.016 * horizontalDirection
                        if (Math.abs(y - root.height/2) > root.height/2) {
                            y = root.height/2
                            direction = (Math.random() < 0.5 ? 1 : -1)
                            speed = (Math.random() * (maxSpeed - minSpeed) + minSpeed)
                            color = weightedColor()
                        }
                        if (x < 0) { x = 0; horizontalDirection *= -1 }
                        if (x > root.width - width) { x = root.width - width; horizontalDirection *= -1 }
                    }
                }
            }
        }
    }

    // Horizontal scanline
    Rectangle {
        id: hScanline
        visible: scanlineEnabled
        width: parent.width
        height: scanlineWidth
        color: scanlineColor
        opacity: 0.9
        y: -scanlineWidth

        Timer {
            interval: 16
            repeat: true
            running: true
            onTriggered: {
                if (!root.closing) {
                    hScanline.y += scanlineSpeed * 0.016 + mouseYOffset * 2.5
                    if (hScanline.y > root.height) hScanline.y = -scanlineWidth
                }
            }
        }
    }

    // Vertical scanline
    Rectangle {
        id: vScanline
        visible: scanlineEnabled
        width: scanlineWidth
        height: parent.height
        color: scanlineColor
        opacity: 0.9
        x: -scanlineWidth

        Timer {
            interval: 16
            repeat: true
            running: true
            onTriggered: {
                if (!root.closing) {
                    vScanline.x += scanlineSpeed * 0.016 + mouseXOffset * 2.5
                    if (vScanline.x > root.width) vScanline.x = -scanlineWidth
                }
            }
        }
    }
}
