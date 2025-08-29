cmake_minimum_required(VERSION 3.14)
project(WaylandWindowMonitor)

set(CMAKE_CXX_STANDARD 17)

find_package(Qt6 REQUIRED COMPONENTS Core)
find_package(PkgConfig REQUIRED)

pkg_check_modules(WAYLAND REQUIRED wayland-client)

include_directories(
    ${WAYLAND_INCLUDE_DIRS}
    ${CMAKE_CURRENT_SOURCE_DIR}
)

add_executable(list-windows
    main.cpp
    wlr-foreign-toplevel-management-unstable-v1-protocol.c
)

target_link_libraries(list-windows
    ${WAYLAND_LIBRARIES}
    Qt6::Core
)
