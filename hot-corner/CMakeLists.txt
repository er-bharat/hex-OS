cmake_minimum_required(VERSION 3.18)
project(OverlayWindow LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)

find_package(Qt6 REQUIRED COMPONENTS Core Quick Gui)
find_package(LayerShellQt REQUIRED)

# Enable AUTOMOC for Q_OBJECT processing
set(CMAKE_AUTOMOC ON)
set(CMAKE_AUTORCC ON)

# Add executable
qt_add_executable(hex-corner
    main.cpp
)

# Add QML resources
qt6_add_resources(hex-corner "qml_resources"
    PREFIX "/"
    FILES main.qml
)

# Link libraries
target_link_libraries(hex-corner
    PRIVATE Qt6::Core Qt6::Quick Qt6::Gui LayerShellQt::Interface
)
