import QtQuick 6.5
import QtQuick.Controls
import QtQuick.Shapes
import QtQuick.Window
import QtQuick.Layouts 1.15

import "Components"

Window {
    id: root

    property int hexWidth: appModel.hexWidth
    property int hexHeight: appModel.hexHeight
    property int hexMargin: appModel.hexMargin
    property int borderWidth: appModel.borderWidth
    property int iconGrid: appModel.iconGrid
    property int iconPpage: appModel.iconPpage
    property int animationDuration: appModel.animationDuration
    property double animationScale: appModel.animationScale
    property string backgroundColor: appModel.backgroundColor
    property string hexFillColor: appModel.fillColor
    property string hexBorderColor: appModel.borderColor
    property string hoveredColor: appModel.hoveredColor
    property string borderHoveredColor: appModel.borderHoveredColor
    property int totalItems: appModel.count
    property string mainFont: appModel.mainFont
    property string subFont: appModel.subFont


    property int currentIndex: 0
    // These will be recalculated for the current page only:
    property var rowSizes: []
    property int rowCount: 0
    // Pagination setup
    property int itemsPerPage: appModel.iconPpage
    property int currentPage: 0
    property int totalPages: Math.ceil(totalItems / itemsPerPage)
    property int previousPage: 0
    property int bounceDirection: 0 // +1 for down, -1 for up

    // calculates how the rows will be arranged
    function updateRowSizes() {
        let remaining = pageModel.count;
        let sizes = [];
        let isEven = true;
        while (remaining > 0) {
            let count = isEven ? iconGrid : iconGrid - 1;
            sizes.push(Math.min(count, remaining));
            remaining -= count;
            isEven = !isEven;
        }
        rowSizes = sizes;
        rowCount = sizes.length;
    }

    // Slices the appmodel in pages acc to instructions
    function updatePageModel() {
        pageModel.clear();
        let start = currentPage * itemsPerPage;
        let end = Math.min(start + itemsPerPage, totalItems);
        for (let i = start; i < end; i++) {
            let app = appModel.get(i);
            pageModel.append({
                "name": app.name,
                "icon": app.icon,
                "exec": app.exec
            });
        }
        updateRowSizes();
    }

    // tells the keyboard navigation what app is selected
    function getRowCol(index) {
        let row = 0;
        let i = index;
        while (row < rowSizes.length && i >= rowSizes[row]) {
            i -= rowSizes[row];
            row++;
        }
        return {
            "row": row,
            "col": i
        };
    }

    // Function to add transparency to hex color string
    function withAlpha(hexColor, alpha) {
        let c = Qt.color(hexColor); // ✅ correct way to convert string to color
        return Qt.rgba(c.r, c.g, c.b, alpha);
    }

    width: screen.width
    height: screen.height
    visible: false
    color: backgroundColor
    flags: Qt.FramelessWindowHint

    SinWaveBackground {
        id: sinBg
        visible:showsinBg
        anchors.fill: parent
    }

    SciFiGridBackground {
        id: sciFiBg
        visible:showsciFiBg
        anchors.fill: parent   // or let it default to 1920x1080

    }

    Component.onCompleted: {
        updatePageModel();
        layoutZoomIn.running = true;
        keyHandler.focus = true;
        // runningWindows.activate(index);
    }
    onCurrentPageChanged: {
        bounceDirection = currentPage > previousPage ? 1 : -1;
        previousPage = currentPage;
        bounceAnimation.restart();
        updatePageModel();
    }
    onTotalItemsChanged: {
        totalPages = Math.ceil(totalItems / itemsPerPage);
        if (currentPage >= totalPages)
            currentPage = totalPages - 1;

        updatePageModel();
    }

    ListModel {
        id: pageModel
    }
    //----------------------------------------Widgets--------------------------------------------

    Item {
        id: widgets
        width: screen.width
        height: screen.height

        transform: Scale {
            id: widgetScale
            xScale: 1
            yScale: 1
            // center the scale on the Item
            origin.x: widgets.width / 2
            origin.y: widgets.height / 2
        }

        opacity: 1

        property int margin: hexMargin  // vertical spacing between hexes
        property int rightMargin: hexMargin

        z: 1000

        ColumnLayout {
            id: hexColumn
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.topMargin: widgets.margin
            anchors.rightMargin: widgets.rightMargin
            spacing: widgets.margin

                // Hex Clock positioned in top right
                HexClock {
                    width: hexWidth * 0.8
                    height: hexHeight * 0.6
                    visible: showClock
                }

                // see networkProvider
                HexNetwork {
                    width: hexWidth * 0.8
                    height: hexHeight * 0.6
                    visible: showNetwork
                }

                // see battery percentage
                HexBattery {
                    visible: showBattery
                    width: hexWidth * 0.8
                    height: hexHeight * 0.6
                    z: 1000
                }

                // weather
                HexWeather {
                    visible: showWeather
                    width: hexWidth * 0.8
                    height: hexHeight * 0.6
                }

                // power buttons
                HexPower {
                    visible: showPower
                    width: hexWidth * 0.8
                    height: hexHeight * 0.6
                }
        }
    }


    //----------------------------------------------------------------------------------------------
    //running apps
    Row {
        id: taskbarRow

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: ((screen.height - layoutArea.height) / 4) / 2
        spacing: 12
        scale: 0
        z: 500

        Repeater {
            model: runningWindows

            delegate: Item {
                id: appIconItem

                property bool hovered: false
                property real visibleScale: 1
                property real opacityValue: 0.9

                width: hexWidth / 2
                height: hexHeight / 2
                opacity: opacityValue
                scale: hovered ? animationScale : visibleScale
                Component.onCompleted: {
                    // Fade and grow in when created
                    opacityValue = 1;
                    visibleScale = 1;
                }
                // Smooth remove trigger when item is destroyed
                onVisibleScaleChanged: {
                    if (visibleScale === 0)
                        opacityValue = 0.2;
                }

                Column {
                    spacing: hexMargin
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: parent.width

                    Item {
                        id: hexWrapper

                        width: hexWidth / 2
                        height: hexHeight / 2
                        anchors.horizontalCenter: parent.horizontalCenter
                        scale: hovered ? animationScale : 1

                        Shape {
                            id: hexagon

                            anchors.fill: parent
                            antialiasing: true

                            ShapePath {
                                strokeWidth: borderWidth / 2
                                strokeColor: hovered ? borderHoveredColor : hexBorderColor
                                fillColor: hovered ? hoveredColor : hexFillColor
                                fillRule: ShapePath.WindingFill
                                capStyle: ShapePath.FlatCap
                                joinStyle: ShapePath.MiterJoin
                                startX: hexagon.width / 2
                                startY: 0

                                PathLine {
                                    x: hexagon.width
                                    y: hexagon.height / 4
                                }

                                PathLine {
                                    x: hexagon.width
                                    y: hexagon.height * 3 / 4
                                }

                                PathLine {
                                    x: hexagon.width / 2
                                    y: hexagon.height
                                }

                                PathLine {
                                    x: 0
                                    y: hexagon.height * 3 / 4
                                }

                                PathLine {
                                    x: 0
                                    y: hexagon.height / 4
                                }

                                PathLine {
                                    x: hexagon.width / 2
                                    y: 0
                                }
                            }

                            // Icon inside
                            Item {
                                anchors.fill: parent

                                Image {
                                    property string cleanedIcon: model.icon.startsWith("qrc:/") ? model.icon.slice(4) : model.icon

                                    anchors.centerIn: parent
                                    width: hexagon.width * 0.5
                                    height: hexagon.height * 0.5
                                    fillMode: Image.PreserveAspectFit
                                    source: cleanedIcon.startsWith("/") ? "file:" + cleanedIcon : cleanedIcon
                                }

                                Timer {
                                    id: hoverDelayTimer
                                    interval: 350
                                    repeat: false
                                    onTriggered: {
                                        if (hovered) {
                                            // runningWindows.activate(index)
                                        }
                                    }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    acceptedButtons: Qt.LeftButton | Qt.RightButton

                                    onEntered: {
                                        hovered = true;
                                        hoverDelayTimer.start();
                                    }
                                    onExited: hovered = false

                                    onClicked: {
                                        if (mouse.button === Qt.LeftButton) {
                                            runningWindows.activate(index);
                                            Qt.quit();
                                        } else if (mouse.button === Qt.RightButton) {
                                            hovered = false;
                                            runningWindows.close(index);
                                            visibleScale = 0;
                                        }
                                    }
                                }
                            }
                        }

                        Behavior on scale {
                            NumberAnimation {
                                duration: animationDuration / 2
                                easing.type: Easing.InOutQuad
                            }
                        }
                    }

                    Text {
                        text: title
                        color: "white"
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        width: parent.width
                        wrapMode: Text.Wrap            // Enable wrapping
                        maximumLineCount: 3            // Limit lines to 3 (Qt 5.10+)
                        elide: Text.ElideNone          // No eliding since we wrap
                        font.pointSize: 9
                        font.family: mainFont
                    }
                }

                Behavior on scale {
                    NumberAnimation {
                        duration: animationDuration
                        easing.type: Easing.OutBack
                    }
                }

                Behavior on opacity {
                    NumberAnimation {
                        duration: animationDuration * 1.5
                        easing.type: Easing.InOutQuad
                    }
                }
            }
        }
    }

    // top searchbar layout.
    Rectangle {
        id: searchBar

        width: 400
        height: 60
        color: "transparent"
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: ((screen.height - layoutArea.height) / 4) / 2
        z: 1
        opacity: 0
        scale: 0
        // Component.onCompleted: {
        //     searchBar.opacity = 1;
        //     searchBar.scale = animationScale;
        // }
        // Optional hover or focus animation for subtle effect
        states: [
            State {
                name: "focused"
                when: searchField.focus

                PropertyChanges {
                    target: searchBar
                    scale: animationScale
                }
            }
        ]
        transitions: [
            Transition {
                from: ""
                to: "focused"
                reversible: true

                NumberAnimation {
                    properties: "scale"
                    duration: animationDuration
                    easing.type: Easing.InOutQuad
                }
            }
        ]

        // hexagonal shape with top and bottom flat
        Shape {
            anchors.fill: parent
            antialiasing: true

            ShapePath {
                strokeWidth: borderWidth * 0.6
                strokeColor: searchField.focus ? borderHoveredColor : hexBorderColor
                fillColor: hexFillColor
                fillRule: ShapePath.WindingFill
                capStyle: ShapePath.FlatCap
                joinStyle: ShapePath.MiterJoin
                startX: searchBar.height / 2
                startY: 0

                PathLine {
                    x: searchBar.width - searchBar.height / 2
                    y: 0
                }

                PathLine {
                    x: searchBar.width
                    y: searchBar.height / 2
                }

                PathLine {
                    x: searchBar.width - searchBar.height / 2
                    y: searchBar.height
                }

                PathLine {
                    x: searchBar.height / 2
                    y: searchBar.height
                }

                PathLine {
                    x: 0
                    y: searchBar.height / 2
                }

                PathLine {
                    x: searchBar.height / 2
                    y: 0
                }
            }
        }

        TextField {
            id: searchField

            // logic to show what appmodel to load
            function updateAppList() {
                if (text === "") {
                    //when first loaded and empty search bar loads from apps.ini
                    appModel.loadFromIni(configPath);
                } else if (text === "/") {
                    //when / is typed in search bar all apps shows.
                    appModel.loadAllDesktopFiles();
                } else {
                    const query = text.startsWith("/") ? text.slice(1) : text; //search even when typed after /
                    appModel.searchDesktopFiles(query);
                }
            }

            anchors.fill: parent
            anchors.margins: 10
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            placeholderText: " type / for all apps.. "
            font.pointSize: 18
            font.family: mainFont
            color: "white"
            selectionColor: "#00aaff"
            background: null
            onTextChanged: {
                root.currentIndex = 0; //selected first item on each search text input.
                updateAppList(); //updates model on search text
            }
            onFocusChanged: updateAppList()
            // key navigation for searchbar
            Keys.onPressed: (event) => {
                if (event.key === Qt.Key_PageDown) {
                    //next page
                    if (root.currentPage < root.totalPages - 1) {
                        root.currentPage++;
                        root.currentIndex = root.currentPage * root.itemsPerPage;
                        event.accepted = true;
                    }
                } else if (event.key === Qt.Key_PageUp) {
                    if (root.currentPage > 0) {
                        // Move to previous page
                        root.currentPage--;
                        root.currentIndex = root.currentPage * root.itemsPerPage;
                    } else {
                        // Already on first page → clear searchField and focus keyHandler
                        searchField.text = "";

                        // Use Qt.callLater to ensure focus change happens after event processing
                        Qt.callLater(() => {
                            keyHandler.forceActiveFocus();
                        });
                    }

                    event.accepted = true;

                } else if (event.key === Qt.Key_Tab) {
                    //hand focus to keyboard navigation
                    event.accepted = true;
                    keyHandler.focus = true;
                } else if (event.key === Qt.Key_Escape) {
                    //to get back to preset apps.ini
                    // 1. Clear text
                    searchField.text = "";
                    // 2. Reset page and index
                    root.currentPage = 0;
                    root.currentIndex = 0;
                    // 3. Refocus to icon grid and first item
                    keyHandler.focus = true;
                    event.accepted = true;
                } else if (event.key === Qt.Key_Down || event.key === Qt.Key_Up ) {
                    //moves focus to apps easier and elegantly
                    event.accepted = true;
                    keyHandler.focus = true;
                } else if (event.key === Qt.Key_Left || event.key === Qt.Key_Right) {
                    // NEW: Shift focus to keyHandler on Left/Right arrow press
                    event.accepted = true;
                    keyHandler.focus = true;
                } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                    //opens searched app
                    if (pageModel.count > 0) {
                        const item = repeater.itemAt(0);
                        if (item && item.parentSequential) {
                            item.parentSequential.running = true;
                        } else {
                            // Fallback in case the animation is not found (e.g. during initial load)
                            const firstApp = pageModel.get(0);
                            launcher.launch(firstApp.exec);
                            Qt.quit();
                        }
                    }
                    event.accepted = true;
                }
            }
        }
        // Animate search bar in on component completion

        Behavior on opacity {
            NumberAnimation {
                duration: animationDuration * 2.5
                easing.type: Easing.OutCubic
            }
        }

        Behavior on scale {
            NumberAnimation {
                duration: animationDuration * 2.5
                easing.type: Easing.OutCubic
            }
        }
    }

    //wrapper for bounce animation on page change purpose of main window.
    Item {
        id: layoutWrapper

        property int bounceOffset: 0 // this is what we'll animate

        width: layoutArea.width
        height: layoutArea.height
        x: (parent.width - width) / 2
        y: (parent.height - height) / 2 + bounceOffset
        z: 500

        //main window which houses hexagonal icons.
        Item {
            id: layoutArea


            transform: Scale {
                id: layoutScale
                xScale: 0
                yScale: 0
                // center the scale on the Item
                origin.x: layoutArea.width / 2
                origin.y: layoutArea.height / 2
            }
            opacity: 1

            width: {
                // dynamically changes width based on no of items set in row
                let maxRowWidth = 0;
                for (let i = 0; i < rowSizes.length; i++) {
                    let count = rowSizes[i];
                    let rowWidth = count * (hexWidth + hexMargin) - hexMargin * 2;
                    if (i % 2 === 1)
                        rowWidth += hexWidth / 2;

                    maxRowWidth = Math.max(maxRowWidth, rowWidth);
                }
                return maxRowWidth;
            }
            //height taking in account margin bw hexagons.
            height: (rowCount - 1) * (hexHeight * 0.75 + hexMargin) + hexHeight
            anchors.centerIn: parent
            // scale: 0

            Repeater {
                id: repeater

                model: pageModel

                delegate: Item {
                    id: delegateRoot

                    property alias parentSequential: parentSequential
                    property int localIndex: index
                    property var pos: root.getRowCol(localIndex)
                    property int row: pos.row
                    property int col: pos.col
                    // Absolute index based on current page and items per page
                    property int absoluteIndex: root.currentPage * root.itemsPerPage + localIndex
                    // Selection logic based on absolute index
                    property bool selected: root.currentIndex === absoluteIndex
                    property int currentLocalIndex: currentIndex - currentPage * itemsPerPage
                    property bool hovered: false

                    width: hexWidth
                    height: hexHeight
                    transformOrigin: Item.Center
                    //positions the icons in honeycomb format like zigsaw pieces accounting for margins.
                    x: col * (hexWidth + hexMargin) + ((row % 2 === 1) ? hexWidth / 2 : 0) + ((row % 2 === 0) ? -hexMargin / 2 : 0)
                    y: row * (hexHeight * 0.75 + hexMargin)
                    scale: hovered || selected ? animationScale : 1
                    opacity: hovered || selected ? 1 : 0.95


                    //launch animation when clicked or entered.

                    SequentialAnimation {
                        id: parentSequential

                        running: false

                        ScriptAction {
                            script: {
                                launcher.launch(appModel.get(absoluteIndex).exec);
                            }
                        }
                        PropertyAnimation {
                            target: parent
                            property: "scale"
                            to: 9 //amount of scale on zoom
                            duration: animationDuration //time of zoom
                            easing.type: Easing.InCubic
                        }
                        ScriptAction {
                            script: Qt.quit()
                        }
                    }
                    //hexagonal shape of icons

                    Shape {
                        anchors.fill: parent
                        antialiasing: true

                        ShapePath {
                            strokeWidth: borderWidth
                            strokeColor: hovered || selected ? borderHoveredColor : hexBorderColor
                            fillColor: hovered || selected ? hoveredColor : hexFillColor
                            fillRule: ShapePath.WindingFill
                            capStyle: ShapePath.FlatCap
                            joinStyle: ShapePath.MiterJoin
                            startX: width / 2
                            startY: 0

                            PathLine {
                                x: width
                                y: height * 0.25
                            }

                            PathLine {
                                x: width
                                y: height * 0.75
                            }

                            PathLine {
                                x: width / 2
                                y: height
                            }

                            PathLine {
                                x: 0
                                y: height * 0.75
                            }

                            PathLine {
                                x: 0
                                y: height * 0.25
                            }

                            PathLine {
                                x: width / 2
                                y: 0
                            }
                        }
                    }
                    //app image

                    Image {
                        property string cleanedIcon: model.icon.startsWith("qrc:/") ? model.icon.slice(4) : model.icon

                        anchors.centerIn: parent
                        width: parent.width * 0.5
                        height: parent.height * 0.5
                        source: cleanedIcon.startsWith("/") ? "file:" + cleanedIcon : cleanedIcon
                        fillMode: Image.PreserveAspectFit
                        smooth: true
                        scale: hovered || selected ? 1.125 : 1

                        Behavior on scale {
                            NumberAnimation {
                                duration: animationDuration / 2
                                easing.type: Easing.InOutQuad
                            }
                        }
                    }
                    //app title

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: width / 4
                        text: model.name
                        font.pointSize: 10
                        font.family: mainFont
                        font.weight: hovered || selected ? Font.Black : Font.Medium
                        color: hovered || selected ? "black" : "white"
                    }

                    MouseArea {
                        // Do not quit or animate
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        onPositionChanged: {
                            // Use mouseX and mouseY instead of injected "mouse"
                            sciFiBg.mouseXOffset = (mouseX - width / 2) / (width / 2)
                            sciFiBg.mouseYOffset = (mouseY - height / 2) / (height / 2)
                        }
                        onEntered: {
                            hovered = true;
                            root.currentIndex = absoluteIndex;
                        }
                        onExited: hovered = false
                        onClicked: (mouse) => {
                            if (mouse.button === Qt.LeftButton) {
                                parentSequential.running = true; // Run animation and quit
                            } else if (mouse.button === Qt.RightButton) {
                                launcher.launchAndRefresh(appModel.get(absoluteIndex).exec, runningWindows); // Just launch the app
                                runningWindows.refresh();
                            }
                        }
                    }

                    //animations for hover effect slight scale

                    Behavior on scale {
                        NumberAnimation {
                            duration: animationDuration / 2
                            easing.type: Easing.InOutQuad
                        }
                    }

                    Behavior on opacity {
                        NumberAnimation {
                            duration: animationDuration / 2
                            easing.type: Easing.InOutQuad
                        }
                    }
                }
            }
        }
    }

    //bounce animation on changing page.
    SequentialAnimation {
        id: bounceAnimation

        running: false

        PropertyAnimation {
            target: layoutWrapper
            property: "bounceOffset"
            to: bounceDirection * 40 //amount of bounce
            duration: animationDuration / 2
            easing.type: Easing.OutCubic
        }

        PropertyAnimation {
            target: layoutWrapper
            property: "bounceOffset"
            to: 0
            duration: animationDuration / 2
            easing.type: Easing.OutBounce
        }
    }

    //animation when the main window launches
    ParallelAnimation {
        id: layoutZoomIn

        running: false

        PropertyAnimation {
            target: layoutScale
            property: "xScale"
            from: 19; to: 1
            duration: animationDuration
            easing.type: Easing.OutCubic
        }
        PropertyAnimation {
            target: layoutScale
            property: "yScale"
            from: 9; to: 1
            duration: animationDuration
            easing.type: Easing.OutCubic
        }
        PropertyAnimation {
            target: layoutArea
            property: "opacity"
            from: 0.2; to: 1
            duration: animationDuration
            easing.type: Easing.OutCubic
        }

        PropertyAnimation {
            target: widgets
            property: "opacity"
            from: 0; to: 1
            duration: animationDuration
            easing.type: Easing.OutCubic
        }
        PropertyAnimation {
            target: widgetScale
            property: "yScale"
            from: 0
            to: 1
            duration: animationDuration
            easing.type: Easing.OutCubic
        }
        PropertyAnimation {
            target: widgetScale
            property: "xScale"
            from: 0
            to: 1
            duration: animationDuration
            easing.type: Easing.OutCubic
        }


        // Delay for 40% of layoutArea animation before starting others
        SequentialAnimation {
            PropertyAnimation {
                // delay: animationDuration * 0.6

                target: searchBar
                property: "scale"
                from: 9
                to: 1
                duration: animationDuration / 1.2
                easing.type: Easing.OutCubic
            }

            PauseAnimation {
                duration: animationDuration * 0.6
            }
        }

        SequentialAnimation {
            PropertyAnimation {
                target: searchBar
                property: "opacity"
                from: 0.8
                to: 1
                duration: animationDuration / 1.2
            }

            PauseAnimation {
                duration: animationDuration * 0.6
            }
        }
        SequentialAnimation {
            PropertyAnimation {
                target: taskbarRow
                property: "scale"
                from: 9
                to: 1
                duration: animationDuration / 1.2
                easing.type: Easing.OutCubic
            }
            PauseAnimation {
                duration: animationDuration * 0.6
            }
        }

        SequentialAnimation {
            PropertyAnimation {
                target: taskbarRow
                property: "opacity"
                from: 0.8
                to: 1
                duration: animationDuration / 1.2
            }
            PauseAnimation {
                duration: animationDuration * 0.6
            }
        }
    }

    // click on background to quit
    MouseArea {
        id: backgroundClickArea

        anchors.fill: parent
        hoverEnabled: true
        z: 0
        onClicked: (mouse) => {
            layoutZoomOut.running = true;
            sciFiBg.closeAnimation()
        }
    }

    //zoomout animation when quitting
    SequentialAnimation {
        id: layoutZoomOut

        running: false

        // All visual elements animate simultaneously here
        ParallelAnimation {
            PropertyAnimation {
                target: layoutScale
                property: "xScale"
                from: 1
                to: 0.3
                duration: animationDuration
                easing.type: Easing.OutCubic
            }
            PropertyAnimation {
                target: layoutScale
                property: "yScale"
                from: 1
                to: 0.1
                duration: animationDuration
                easing.type: Easing.OutCubic
            }
            PropertyAnimation {
                target: widgetScale
                property: "yScale"
                from: 1
                to: 0.1
                duration: animationDuration
                easing.type: Easing.OutCubic
            }
            PropertyAnimation {
                target: widgetScale
                property: "xScale"
                from: 1
                to: 0
                duration: animationDuration
                easing.type: Easing.OutCubic
            }
            PropertyAnimation {
                target: layoutArea
                property: "opacity"
                from: 1
                to: 0
                duration: animationDuration
                easing.type: Easing.OutCubic
            }
            PropertyAnimation {
                target: searchBar
                property: "scale"
                from: 1
                to: 0
                duration: animationDuration
                easing.type: Easing.InCubic
            }
            PropertyAnimation {
                target: searchBar
                property: "opacity"
                from: 1
                to: 0
                duration: animationDuration
            }
            PropertyAnimation {
                target: taskbarRow
                property: "opacity"
                from: 1
                to: 0
                duration: animationDuration
            }
            PropertyAnimation {
                target: taskbarRow
                property: "scale"
                from: 1
                to: 0
                duration: animationDuration
                easing.type: Easing.InCubic
            }
            PropertyAnimation {
                target: widgets
                property: "opacity"
                from: 1
                to: 0
                duration: animationDuration
            }
        }
        // Quit after the animation
        ScriptAction {
            script: Qt.quit()
        }

    }

    // Help window (can also use Popup or Window)
    HelpDialog {
        id: helpDialog
        visible: false
    }

    //entire keyboard navigation and mousewheel to change page.
    Item {
        id: keyHandler

        focus: true
        anchors.fill: parent
        Keys.onPressed: (event) => {
            let total = totalItems;
            let current = currentIndex;
            let pos = getRowCol(current - currentPage * itemsPerPage); // Local index in page
            switch (event.key) {
            case Qt.Key_Left:
                //on first item chnges to previous page
                if (currentIndex > 0) {
                    currentIndex--;
                    if (currentIndex < currentPage * itemsPerPage)
                        currentPage--;

                }
                event.accepted = true;
                break;
            case Qt.Key_Right:
                let isLastItem = currentIndex === totalItems - 1;
                if (isLastItem) {
                    // Last item → move to searchField and insert `/`
                    searchField.forceActiveFocus();
                    searchField.text = "/";
                    searchField.cursorPosition = 1;
                } else {
                    currentIndex++;
                    if (currentIndex >= (currentPage + 1) * itemsPerPage)
                        currentPage++;

                }
                event.accepted = true;
                break;
            case Qt.Key_Up:
            {
                let localIndex = currentIndex - currentPage * itemsPerPage;
                let pos = getRowCol(localIndex);
                let newRow = pos.row - 1;

                if (newRow >= 0) {
                    // Move up within current page
                    let col = Math.min(pos.col, rowSizes[newRow] - 1);
                    let offset = rowSizes.slice(0, newRow).reduce((a, b) => a + b, 0);
                    currentIndex = currentPage * itemsPerPage + offset + col;
                } else if (currentPage > 0) {
                    // Move to previous page
                    currentPage--;
                    Qt.callLater(() => {
                        let lastRow = rowSizes.length - 1;
                        let col = Math.min(pos.col, rowSizes[lastRow] - 1);
                        let offset = rowSizes.slice(0, lastRow).reduce((a, b) => a + b, 0);
                        currentIndex = currentPage * itemsPerPage + offset + col;
                    });
                } else {
                    // Top row of first page → clear searchField and focus keyHandler
                    searchField.text = "";
                    keyHandler.forceActiveFocus();
                }
                event.accepted = true;
                break;
            };

            case Qt.Key_Down:
            {
                let localIndex = currentIndex - currentPage * itemsPerPage;
                let pos = getRowCol(localIndex);
                let nextRow = pos.row + 1;

                if (nextRow < rowSizes.length) {
                    // Move down within current page
                    let col = Math.min(pos.col, rowSizes[nextRow] - 1);
                    let offset = rowSizes.slice(0, nextRow).reduce((a, b) => a + b, 0);
                    currentIndex = currentPage * itemsPerPage + offset + col;
                } else if (currentPage < totalPages - 1) {
                    // Move to next page, same column if possible
                    currentPage++;
                    Qt.callLater(() => {
                        let col = Math.min(pos.col, rowSizes[0] - 1);
                        currentIndex = currentPage * itemsPerPage + col;
                    });
                } else {
                    // Already at last row of last page → focus searchField like Right key
                    searchField.forceActiveFocus();
                    if (searchField.text === "")
                        searchField.text = "/";
                    searchField.cursorPosition = searchField.text.length;
                }
                event.accepted = true;
                break;
            };

            case Qt.Key_PageDown:
                if (currentPage < totalPages - 1) {
                    currentPage++;
                    currentIndex = currentPage * itemsPerPage;
                } else {
                    // Already on last page → focus search
                    searchField.forceActiveFocus();
                    if (searchField.text === "")
                        searchField.text = "/";

                    searchField.cursorPosition = searchField.text.length;
                }
                event.accepted = true;
                break;
            case Qt.Key_PageUp:
                if (searchField.activeFocus && searchField.text === "/") {
                    // Exit search mode and return to key navigation
                    searchField.text = "";
                    keyHandler.forceActiveFocus();
                    event.accepted = true;
                    break;
                }

                if (currentPage > 0) {
                    // Move to previous page
                    currentPage--;
                    currentIndex = currentPage * itemsPerPage;
                } else {
                    // Already on the first page → focus search, clear it, then refocus keyHandler
                    searchField.forceActiveFocus();
                    searchField.text = "";
                    keyHandler.forceActiveFocus();
                }

                event.accepted = true;
                break;

            case Qt.Key_Return:
            case Qt.Key_Enter:
                let localIndex = currentIndex - currentPage * itemsPerPage;
                let appItem = repeater.itemAt(localIndex);
                if (appItem && appItem.parentSequential) {
                    appItem.parentSequential.running = true;
                    event.accepted = true;
                }
                break;
            case Qt.Key_Escape:
                //exit app
                if (!layoutZoomOut.running) {
                    layoutZoomOut.running = true;
                    event.accepted = true;
                }
                break;
            case Qt.Key_Slash:
                //all apps
                searchField.forceActiveFocus();
                searchField.text = "/";
                searchField.cursorPosition = 1; // Move cursor to end
                event.accepted = true;
                break;
            case Qt.Key_F1:
                // Toggle help window
                if (helpDialog.visible)
                    helpDialog.close();
                else
                    helpDialog.open();
                event.accepted = true;
                break;
            }
            // can start typing without first focusing searchbar
            if (!event.accepted && event.text && event.text.length === 1 && event.key !== Qt.Key_Tab) {
                searchField.forceActiveFocus();
                searchField.text += event.text;
                searchField.cursorPosition = searchField.text.length;
                event.accepted = true;
            }
        }

        MouseArea {
            id: wheelCatcher

            property int scrollDeltaAccum: 0
            property int scrollThreshold: 90 // Standard mouse wheel delta (120 per notch)
            property bool canScroll: true // throttle flag

            onPositionChanged: {
                // Use mouseX and mouseY instead of injected "mouse"
                sciFiBg.mouseXOffset = (mouseX - width / 2) / (width / 2)
                sciFiBg.mouseYOffset = (mouseY - height / 2) / (height / 2)
            }

            anchors.fill: parent
            acceptedButtons: Qt.NoButton
            hoverEnabled: true
            // preventStealing: true
            propagateComposedEvents: true

            Timer {
                id: scrollTimer
                interval: 200
                repeat: false
                onTriggered: wheelCatcher.canScroll = true
            }

            onWheel: (wheel) => {
                if (!canScroll) {
                    wheel.accepted = true;
                    return;
                }

                scrollDeltaAccum += wheel.angleDelta.y;

                if (scrollDeltaAccum >= scrollThreshold) {
                    if (searchField.activeFocus && searchField.text === "/" && root.currentPage === 0) {
                        searchField.text = "";
                        keyHandler.forceActiveFocus();
                    } else if (root.currentPage > 0) {
                        root.currentPage--;
                        root.currentIndex = root.currentPage * root.itemsPerPage;
                    }
                    scrollDeltaAccum = 0;
                    canScroll = false;
                    scrollTimer.start();
                } else if (scrollDeltaAccum <= -scrollThreshold) {
                    if (root.currentPage < root.totalPages - 1) {
                        root.currentPage++;
                        root.currentIndex = root.currentPage * root.itemsPerPage;
                    } else {
                        searchField.forceActiveFocus();
                        if (searchField.text === "")
                            searchField.text = "/";
                        searchField.cursorPosition = searchField.text.length;
                    }
                    scrollDeltaAccum = 0;
                    canScroll = false;
                    scrollTimer.start();
                }

                wheel.accepted = true;
            }
        }

    }

    Rectangle {
        id: hoverBlocker
        anchors.fill: parent
        color: "transparent"
        visible: layoutZoomIn.running
        z: 9999

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            enabled: layoutZoomIn.running
            acceptedButtons: Qt.NoButton  // hover only, clicks pass through
        }
    }

}
