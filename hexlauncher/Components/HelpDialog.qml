import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Window 2.15

Dialog {
    id: helpDialog
    width: Math.min(800, Screen.width * 0.8)
    title: "Help"
    modal: true
    standardButtons: Dialog.Ok
    anchors.centerIn: parent
    focus: false

    Keys.onPressed: (event) => {
        if (event.key === Qt.Key_F1) {
            helpDialog.close()
            event.accepted = true
        }
    }

    contentItem: Text {
        text:
            "🛠️ HexLauncher Help\n\n" +
            "🖱 Mouse Actions:\n" +
            "• Left Click on an app: Launch app **with zoom animation**, then quit launcher.\n" +
            "• Right Click on an app: Launch app **immediately**, no animation, and **launcher stays open**.\n\n" +
            "• left click on the background closes launcher \n" +
            "• mouse scroll changes page \n\n" +
            "⌨️ Keyboard Shortcuts:\n" +
            "• key navigation enter opens it and \n" +
            "• pgup down changes pages \n" +
            "• tab toggles focus of search bar \n" +
            "• / opens in all app mode and search mode down switches focus to key navigation \n" +
            "• you can start typing without focusing the searchbar \n" +
            "• F1: Toggle this Help window.\n" +
            "• / (Slash): Focus the search field and begin searching apps.\n" +
            "• Esc in searchbar when have some text clears it and shows the apps.ini apps \n" +
            "• Esc: Exit the launcher with a zoom-out animation.\n\n" +
            "💡 Notes:\n" +
            "• Hovering over an app will highlight it.\n" +
            "• Only a fixed number of apps may be shown at a time depending on layout settings.\n" +
            "• You can customize apps and layout via `apps.ini`.\n\n" +
            "• at bottom row is current running apps \n\n" +
            "Right Bar \n" +
            "• network module have wifi selector & power buttons need to be double clicked"
        color: "red"
        wrapMode: Text.Wrap
        padding: 10
    }
}
