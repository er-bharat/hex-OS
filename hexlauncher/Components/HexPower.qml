import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import QtQuick.Shapes 1.15

Item {
    id: hexPower


    // --- Hexagon Shape ---
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
            startX: hexPower.width / 2
            startY: 0

            PathLine { x: hexPower.width; y: hexPower.height * 0.25 }
            PathLine { x: hexPower.width; y: hexPower.height * 0.75 }
            PathLine { x: hexPower.width / 2; y: hexPower.height }
            PathLine { x: 0; y: hexPower.height * 0.75 }
            PathLine { x: 0; y: hexPower.height * 0.25 }
            PathLine { x: hexPower.width / 2; y: 0 }
        }
    }

    // --- Power Control Column ---
    Column {
        anchors.centerIn: parent
        spacing: 6

        Text {
            text: "Power"
            font.pointSize: 11
            color: "#AAAAAA"
            horizontalAlignment: Text.AlignHCenter
            anchors.horizontalCenter: parent.horizontalCenter
        }

        Grid {
            columns: 2
            spacing: 6
            anchors.horizontalCenter: parent.horizontalCenter

            // --- Shutdown ---
            Item {
                width: 32; height: 32
                property bool hovered: false
                scale: hovered ? 1.1 : 1

                Image { anchors.fill: parent; source: "qrc:/images/shutdown.svg"; fillMode: Image.PreserveAspectFit }

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    acceptedButtons: Qt.LeftButton
                    onDoubleClicked: powerControl.shutdown()
                    onEntered: parent.hovered = true
                    onExited: parent.hovered = false

                    ToolTip.visible: parent.hovered
                    ToolTip.text: "Shutdown"
                }

                Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.InOutQuad } }
            }

            // --- Reboot ---
            Item {
                width: 32; height: 32
                property bool hovered: false
                scale: hovered ? 1.1 : 1

                Image { anchors.fill: parent; source: "qrc:/images/reboot.svg"; fillMode: Image.PreserveAspectFit }

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    acceptedButtons: Qt.LeftButton
                    onDoubleClicked: powerControl.reboot()
                    onEntered: parent.hovered = true
                    onExited: parent.hovered = false

                    ToolTip.visible: parent.hovered
                    ToolTip.text: "Reboot"
                }

                Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.InOutQuad } }
            }

            // --- Logout ---
            Item {
                width: 32; height: 32
                property bool hovered: false
                scale: hovered ? 1.1 : 1

                Image { anchors.fill: parent; source: "qrc:/images/logout.svg"; fillMode: Image.PreserveAspectFit }

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    acceptedButtons: Qt.LeftButton
                    onDoubleClicked: powerControl.logout()
                    onEntered: parent.hovered = true
                    onExited: parent.hovered = false

                    ToolTip.visible: parent.hovered
                    ToolTip.text: "Logout"
                }

                Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.InOutQuad } }
            }

            // --- Suspend ---
            Item {
                width: 32; height: 32
                property bool hovered: false
                scale: hovered ? 1.1 : 1

                Image { anchors.fill: parent; source: "qrc:/images/suspend.svg"; fillMode: Image.PreserveAspectFit }

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    acceptedButtons: Qt.LeftButton
                    onDoubleClicked: powerControl.suspend()
                    onEntered: parent.hovered = true
                    onExited: parent.hovered = false

                    ToolTip.visible: parent.hovered
                    ToolTip.text: "Suspend"
                }

                Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.InOutQuad } }
            }
        }
    }
}
