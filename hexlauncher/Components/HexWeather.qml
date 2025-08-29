import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import QtQuick.Shapes 1.15

Item {
    id: hexWeather


    property string city: appModel.weatherLocation
    property string temperature: "--°C"
    property string condition: "Loading..."
    property string icon: ""
    property color hexFillColor: "#222"
    property real borderWidth: 2

    function updateWeather() {
        if (city === "") return;
        var xhr = new XMLHttpRequest();
        var apiKey = appModel.apiKey;
        var url = "https://api.openweathermap.org/data/2.5/weather?q=" + city + "&appid=" + apiKey + "&units=metric";

        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE) {
                if (xhr.status === 200) {
                    var response = JSON.parse(xhr.responseText);
                    hexWeather.temperature = Math.round(response.main.temp) + "°C";
                    hexWeather.condition = response.weather[0].main;
                    hexWeather.icon = response.weather[0].icon;
                } else {
                    hexWeather.temperature = "--°C";
                    hexWeather.condition = "N/A";
                    hexWeather.icon = "";
                    console.log("Failed to fetch weather: " + xhr.status);
                }
            }
        }

        xhr.open("GET", url);
        xhr.send();
    }

    Timer {
        interval: 10000
        running: true
        repeat: true
        onTriggered: hexWeather.updateWeather()
    }

    Component.onCompleted: hexWeather.updateWeather()

    // --- Hexagon Shape ---
    Shape {
        anchors.fill: parent
        antialiasing: true

        ShapePath {
            strokeWidth: borderWidth
            strokeColor: "#888"
            fillColor: hexFillColor
            fillRule: ShapePath.WindingFill
            capStyle: ShapePath.FlatCap
            joinStyle: ShapePath.MiterJoin
            startX: hexWeather.width / 2
            startY: 0

            PathLine { x: hexWeather.width; y: hexWeather.height * 0.25 }
            PathLine { x: hexWeather.width; y: hexWeather.height * 0.75 }
            PathLine { x: hexWeather.width / 2; y: hexWeather.height }
            PathLine { x: 0; y: hexWeather.height * 0.75 }
            PathLine { x: 0; y: hexWeather.height * 0.25 }
            PathLine { x: hexWeather.width / 2; y: 0 }
        }
    }

    // --- Weather UI ---
    Column {
        anchors.centerIn: parent
        spacing: 4

        TextField {
            id: cityField
            text: hexWeather.city
            font.pointSize: 11
            color: "#AAAAAA"
            horizontalAlignment: Text.AlignHCenter
            anchors.horizontalCenter: parent.horizontalCenter
            background: Rectangle { color: "transparent" }
            onEditingFinished: {
                hexWeather.city = text
                hexWeather.updateWeather()
            }
        }

        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 4

            Image {
                source: hexWeather.icon !== "" ? "https://openweathermap.org/img/wn/" + hexWeather.icon + "@2x.png" : ""
                width: 32
                height: 32
                fillMode: Image.PreserveAspectFit
            }

            Text {
                text: hexWeather.temperature
                font.pointSize: 15
                font.family: mainFont
                font.weight: Font.Black
                color: "#00AACC"
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        Text {
            text: hexWeather.condition
            font.pointSize: 10
            color: "#AAAAAA"
            anchors.horizontalCenter: parent.horizontalCenter
        }
    }
}
