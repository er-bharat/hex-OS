import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Shapes 1.15
import QtQuick.Window 2.15

Window {
    // visibility: Window.FullScreen
    // visible: true

    id: root

    property string mode: osdMode
    property int value: osdValue
    property bool muted: osdMuted

    width: 1900
    height: 1240
    color: "transparent"
    flags: Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint | Qt.Tool

    Rectangle {
        anchors.centerIn: parent
        width: AppModel.HexWidth
        height: AppModel.HexHeight
        radius: 10
        color: "#000000cc"

        // Hexagon Progress
        Item {
            id: hexagonBox

            property real stroke: root.muted ? 0 : 4 + (92 * root.value / 100)

            anchors.centerIn: parent
            width: AppModel.HexWidth
            height: AppModel.HexHeight

            Shape {
                anchors.fill: parent
                antialiasing: false

                // Background hexagon
                ShapePath {
                    strokeWidth: AppModel.BorderWidth
                    strokeColor: AppModel.BorderColor
                    fillColor: AppModel.Color
                    fillRule: ShapePath.WindingFill
                    capStyle: ShapePath.FlatCap
                    joinStyle: ShapePath.MiterJoin
                    startX: hexagonBox.width / 2
                    startY: 0

                    PathLine {
                        x: hexagonBox.width
                        y: hexagonBox.height * 0.25
                    }

                    PathLine {
                        x: hexagonBox.width
                        y: hexagonBox.height * 0.75
                    }

                    PathLine {
                        x: hexagonBox.width / 2
                        y: hexagonBox.height
                    }

                    PathLine {
                        x: 0
                        y: hexagonBox.height * 0.75
                    }

                    PathLine {
                        x: 0
                        y: hexagonBox.height * 0.25
                    }

                    PathLine {
                        x: hexagonBox.width / 2
                        y: 0
                    }

                }

                // Foreground progress hexagon
                ShapePath {
                    strokeWidth: hexagonBox.stroke
                    strokeColor: root.mode === "brightness" ? AppModel.HoveredColor : AppModel.BorderHoveredColor
                    fillColor: "transparent"
                    fillRule: ShapePath.WindingFill
                    capStyle: ShapePath.FlatCap
                    joinStyle: ShapePath.MiterJoin
                    startX: hexagonBox.width / 2
                    startY: 0

                    PathLine {
                        x: hexagonBox.width
                        y: hexagonBox.height * 0.25
                    }

                    PathLine {
                        x: hexagonBox.width
                        y: hexagonBox.height * 0.75
                    }

                    PathLine {
                        x: hexagonBox.width / 2
                        y: hexagonBox.height
                    }

                    PathLine {
                        x: 0
                        y: hexagonBox.height * 0.75
                    }

                    PathLine {
                        x: 0
                        y: hexagonBox.height * 0.25
                    }

                    PathLine {
                        x: hexagonBox.width / 2
                        y: 0
                    }

                    // Animate strokeWidth smoothly
                    Behavior on strokeWidth {
                        NumberAnimation {
                            duration: 150
                            easing.type: Easing.InOutQuad
                        }

                    }

                }

            }

            // Center percent text
            Text {
                text: root.mode === "mute" ? "Muted" : root.value + "%"
                anchors.centerIn: parent
                color: "white"
                font.pixelSize: 16
                font.family: AppModel.mainFont
                font.bold: true
            }

        }

    }

}
