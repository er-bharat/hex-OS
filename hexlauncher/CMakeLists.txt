cmake_minimum_required(VERSION 3.18)
project(OverlayWindow LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_AUTOMOC ON)
set(CMAKE_AUTORCC ON)

find_package(Qt6 REQUIRED COMPONENTS Core Quick Gui)
find_package(LayerShellQt REQUIRED)

qt_add_executable(hexlauncher
    main.cpp
)

# qt6_add_resources(hexlauncher "qml_resources"
#     PREFIX "/"
#     FILES main.qml
# )

qt6_add_resources(hexlauncher "qml_resources"
    PREFIX "/"
    FILES main.qml resources.qrc
)


target_link_libraries(hexlauncher
    PRIVATE Qt6::Core Qt6::Quick Qt6::Gui LayerShellQt::Interface
)
