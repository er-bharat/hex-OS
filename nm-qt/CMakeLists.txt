cmake_minimum_required(VERSION 3.16)
project(Qt6WiFiManager)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_AUTOMOC ON)

find_package(Qt6 REQUIRED COMPONENTS Widgets)

add_executable(nmqt main.cpp)
target_link_libraries(nmqt Qt6::Widgets)
