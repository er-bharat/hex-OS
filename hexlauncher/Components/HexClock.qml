import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import QtQuick.Shapes 1.15

Item {
    id: hexClock

    // --- Core properties ---
    property string city: "Local"
    property string gmtOffset: ""
    property string currentTime: ""
    property string currentDate: ""
    property real borderWidth: 2

    // --- Timezone map ---
    property var cityToGMT: {
        "Local": "", "UTC": "+00:00", "Abu Dhabi": "+04:00", "Accra": "+00:00", "Almaty": "+06:00",
        "Amsterdam": "+01:00", "Anadyr": "+12:00", "Athens": "+02:00", "Baghdad": "+03:00",
        "Bangkok": "+07:00", "Beijing": "+08:00", "Belgrade": "+01:00", "Berlin": "+01:00",
        "Bogota": "-05:00", "Bucharest": "+02:00", "Buenos Aires": "-03:00", "Budapest": "+01:00",
        "Caracas": "-04:00", "Chennai": "+05:30", "Chongqing": "+08:00", "Colombo": "+05:30",
        "Damascus": "+02:00", "Dhaka": "+06:00", "Dili": "+09:00", "Dubai": "+04:00",
        "Dublin": "+00:00", "Edinburgh": "+00:00", "Guatemala City": "-06:00", "Hanoi": "+07:00",
        "Hong Kong": "+08:00", "Istanbul": "+03:00", "Jakarta": "+07:00", "Karachi": "+05:00",
        "Kathmandu": "+05:45", "Kiev": "+02:00", "Kolkata": "+05:30", "Krasnoyarsk": "+07:00",
        "Kuala Lumpur": "+08:00", "Kuwait City": "+03:00", "Lima": "-05:00", "Lisbon": "+00:00",
        "London": "+00:00", "Los Angeles": "-08:00", "Madrid": "+01:00", "Managua": "-06:00",
        "Manila": "+08:00", "Mexico City": "-06:00", "Minsk": "+03:00", "Montevideo": "-03:00",
        "Moscow": "+03:00", "Mumbai": "+05:30", "Muscat": "+04:00", "Nairobi": "+03:00",
        "New Delhi": "+05:30", "New York": "-05:00", "Novosibirsk": "+07:00", "Osaka": "+09:00",
        "Oslo": "+01:00", "Paris": "+01:00", "Perth": "+08:00", "Port Moresby": "+10:00",
        "Praia": "-01:00", "Reykjavik": "+00:00", "Riyadh": "+03:00", "Rome": "+01:00",
        "Sapporo": "+09:00", "Santiago": "-04:00", "Sao Paulo": "-03:00", "Seoul": "+09:00",
        "Singapore": "+08:00", "Sri Jayawardenepura": "+05:30", "Stockholm": "+01:00",
        "Sydney": "+10:00", "Taipei": "+08:00", "Tehran": "+03:30", "Tokyo": "+09:00",
        "Vladivostok": "+10:00", "Warsaw": "+01:00", "Zurich": "+01:00"
    }

    // --- Day/Night theme ---
    property color dayBackgroundColor: "lightblue"
    property color nightBackgroundColor: "#222"
    property color hexFillColor: nightBackgroundColor
    property color dayTextColor: "black"
    property color nightTextColor: "#AAAAAA"
    property bool isDaytime: true

    // --- Helper functions ---
    function parseOffset(offsetStr) {
        var sign = offsetStr[0] === "-" ? -1 : 1
        var parts = offsetStr.substring(1).split(":")
        var hours = parseInt(parts[0])
        var minutes = parseInt(parts[1])
        return sign * ((hours * 60 + minutes) * 60000)
    }

    function updateTime() {
        var now = new Date()
        var cityTime = now

        if (gmtOffset !== "") {
            var utc = now.getTime() + now.getTimezoneOffset() * 60000
            cityTime = new Date(utc + parseOffset(gmtOffset))
        }

        currentTime = Qt.formatTime(cityTime, "hh:mm:ss")
        currentDate = Qt.formatDate(cityTime, "ddd, MMM d")

        var hour = cityTime.getHours()
        isDaytime = hour >= 6 && hour < 18
        hexFillColor = isDaytime ? dayBackgroundColor : nightBackgroundColor
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: hexClock.updateTime()
    }

    Component.onCompleted: hexClock.updateTime()

    // --- Hexagon shape ---
    Shape {
        anchors.fill: parent
        antialiasing: true
        ShapePath {
            strokeWidth: hexClock.borderWidth / 2
            strokeColor: "#888"
            fillColor: hexClock.hexFillColor
            fillRule: ShapePath.WindingFill
            capStyle: ShapePath.FlatCap
            joinStyle: ShapePath.MiterJoin

            startX: hexClock.width / 2
            startY: 0
            PathLine { x: hexClock.width; y: hexClock.height * 0.25 }
            PathLine { x: hexClock.width; y: hexClock.height * 0.75 }
            PathLine { x: hexClock.width / 2; y: hexClock.height }
            PathLine { x: 0; y: hexClock.height * 0.75 }
            PathLine { x: 0; y: hexClock.height * 0.25 }
            PathLine { x: hexClock.width / 2; y: 0 }
        }
    }

    // --- Clock UI ---
    Column {
        anchors.centerIn: parent
        spacing: 6

        ComboBox {
            id: cityCombo
            width: 100
            model: Object.keys(hexClock.cityToGMT)
            currentIndex: model.indexOf("Local")
            font.pointSize: 11
            padding: 6
            background: Rectangle { color: "transparent"; radius: 6 }
            contentItem: Text {
                text: cityCombo.currentText
                color: hexClock.isDaytime ? hexClock.dayTextColor : hexClock.nightTextColor
                font.pointSize: 11
                verticalAlignment: Text.AlignVCenter
                horizontalAlignment: Text.AlignHCenter
            }
            delegate: ItemDelegate {
                width: cityCombo.width
                text: modelData
                font.pointSize: 11
                background: Rectangle { color: cityCombo.highlighted ? "#00AACC33" : "transparent" }
                onClicked: cityCombo.currentIndex = index
            }
            onCurrentTextChanged: {
                hexClock.city = currentText
                hexClock.gmtOffset = hexClock.cityToGMT[currentText] || ""
                hexClock.updateTime()
            }
        }

        Text {
            text: hexClock.currentTime
            font.pointSize: 14;
            font.weight: Font.Black
            color: hexClock.isDaytime ? hexClock.dayTextColor : hexClock.nightTextColor
            horizontalAlignment: Text.AlignHCenter

        }
        Text {
            text: hexClock.currentDate
            font.pointSize: 10
            color: hexClock.isDaytime ? hexClock.dayTextColor : hexClock.nightTextColor
            anchors.horizontalCenter: parent.horizontalCenter  // <-- this centers the Text element
            horizontalAlignment: Text.AlignHCenter
        }

    }
}
