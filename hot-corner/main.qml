import QtQuick 2.15
import QtQuick.Window 2.15
import App 1.0

Window {
    id: root
    width: 4
    height: 4
    color: "transparent"  // keep window fully transparent

    AppLauncher { id: launcher }

    Rectangle {
        id: overlay
        anchors.fill: parent
        color: "red"  // default semi-transparent

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true

            onEntered: {
                launcher.launchKitty()
                overlay.color = "#39FF14"  // neon green
            }
            onExited: {
                overlay.color = "red"  // back to semi-transparent
            }
        }
    }

}
