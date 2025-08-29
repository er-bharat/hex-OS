import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import QtQuick.Shapes 1.15

Item {
    id: hexNetwork

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

            startX: hexNetwork.width / 2
            startY: 0
            PathLine { x: hexNetwork.width; y: hexNetwork.height * 0.25 }
            PathLine { x: hexNetwork.width; y: hexNetwork.height * 0.75 }
            PathLine { x: hexNetwork.width / 2; y: hexNetwork.height }
            PathLine { x: 0; y: hexNetwork.height * 0.75 }
            PathLine { x: 0; y: hexNetwork.height * 0.25 }
            PathLine { x: hexNetwork.width / 2; y: 0 }
        }
    }

    // --- Auto-update Timer ---
    Timer {
        interval: 5000
        running: true
        repeat: true
        onTriggered: networkProvider.updateNetworkInfo()
    }

    // --- Network Info Display ---
    Column {
        anchors.centerIn: parent
        spacing: 4

        Text {
            text: networkProvider.networkType
            font.pointSize: 11
            color: "#AAAAAA"
            horizontalAlignment: Text.AlignHCenter
            anchors.horizontalCenter: parent.horizontalCenter
        }

        Text {
            text: networkProvider.networkName.length > 11 ? networkProvider.networkName.substring(0, 11) : networkProvider.networkName
            font.pointSize: 13
            font.weight: Font.Black
            font.family: mainFont
            color: borderHoveredColor
            horizontalAlignment: Text.AlignHCenter
            anchors.horizontalCenter: parent.horizontalCenter
            wrapMode: Text.Wrap
        }
    }

    // --- Clickable Area ---
    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            networkProvider.openNetworkManager()
            Qt.quit()
        }
    }
}
