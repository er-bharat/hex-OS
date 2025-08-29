import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import QtQuick.Shapes 1.15

Item {
    id: hexBattery


    // --- Hexagonal background ---
    Shape {
        anchors.fill: parent
        antialiasing: true

        ShapePath {
            strokeWidth: borderWidth / 2
            strokeColor: "#888"
            fillColor: "#222"
            fillRule: ShapePath.WindingFill
            capStyle: ShapePath.FlatCap
            joinStyle: ShapePath.MiterJoin
            startX: hexBattery.width / 2
            startY: 0

            PathLine { x: hexBattery.width; y: hexBattery.height * 0.25 }
            PathLine { x: hexBattery.width; y: hexBattery.height * 0.75 }
            PathLine { x: hexBattery.width / 2; y: hexBattery.height }
            PathLine { x: 0; y: hexBattery.height * 0.75 }
            PathLine { x: 0; y: hexBattery.height * 0.25 }
            PathLine { x: hexBattery.width / 2; y: 0 }
        }
    }

    // --- Mouse interaction ---
    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.ArrowCursor
        onClicked: console.log("Hexagon clicked")
    }

    // --- Timer to update battery ---
    Timer {
        interval: 10000
        running: true
        repeat: true
        onTriggered: batteryProvider.updateBattery()
    }

    // --- Column for battery UI ---
    Column {
        anchors.centerIn: parent
        spacing: 4

        Text {
            text: "Battery"
            font.pointSize: 11
            color: "#AAAAAA"
            horizontalAlignment: Text.AlignHCenter
            anchors.horizontalCenter: parent.horizontalCenter
        }

        // --- Row for icons and battery percentage ---
        Row {
            spacing: 20
            anchors.horizontalCenter: parent.horizontalCenter

            // Volume Icon
            Item {
                width: 32
                height: 32

                Image {
                    id: volumeIcon
                    anchors.fill: parent
                    source: "qrc:/images/volume.svg"
                    fillMode: Image.PreserveAspectFit
                }

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    acceptedButtons: Qt.LeftButton | Qt.MiddleButton

                    onClicked: (mouse) => {
                        if (mouse.button === Qt.LeftButton) {
                            console.log("Volume icon clicked")
                        } else if (mouse.button === Qt.MiddleButton) {
                            console.log("Middle click - Mute volume")
                            osdController.volMute()
                        }
                    }

                    onWheel: (wheel) => {
                        wheel.accepted = true
                        if (wheel.angleDelta.y > 0) {
                            console.log("Volume up")
                            osdController.volUp()
                        } else {
                            console.log("Volume down")
                            osdController.volDown()
                        }
                    }
                }
            }

            // Battery Percentage
            Text {
                text: batteryProvider.percentage >= 0 ? batteryProvider.percentage + "%" : "N/A"
                font.pointSize: 15
                font.family: mainFont
                font.weight: Font.Black
                color: batteryProvider.percentage < 20 ? "red" : borderHoveredColor
                horizontalAlignment: Text.AlignHCenter
            }

            // Brightness Icon
            Item {
                width: 32
                height: 32

                Image {
                    id: brightnessIcon
                    anchors.fill: parent
                    source: "qrc:/images/brightness.svg"
                    fillMode: Image.PreserveAspectFit
                }

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    acceptedButtons: Qt.NoButton

                    onClicked: console.log("Brightness icon clicked")

                    onWheel: (wheel) => {
                        wheel.accepted = true
                        if (wheel.angleDelta.y > 0) {
                            console.log("Brightness up")
                            osdController.dispUp()
                        } else {
                            console.log("Brightness down")
                            osdController.dispDown()
                        }
                    }
                }
            }
        }

        // --- Battery Status ---
        Text {
            text: batteryProvider.status
            font.pointSize: 10
            color: "#AAAAAA"
            horizontalAlignment: Text.AlignHCenter
            anchors.horizontalCenter: parent.horizontalCenter
        }
    }
}
