cmake_minimum_required(VERSION 3.21)
project(AnserinCore LANGUAGES C CXX)
set(CMAKE_AUTOMOC ON)
find_package(Qt6 REQUIRED COMPONENTS Qml)
find_package(PkgConfig REQUIRED)
pkg_check_modules(PIPEWIRE REQUIRED IMPORTED_TARGET libpipewire-0.3)
pkg_check_modules(SNDFILE REQUIRED IMPORTED_TARGET sndfile)
add_library(anserincore MODULE plugin.cpp sfx.cpp sfx.h)
target_link_libraries(anserincore PRIVATE Qt6::Qml PkgConfig::PIPEWIRE PkgConfig::SNDFILE)
target_compile_features(anserincore PRIVATE cxx_std_17)
target_compile_options(anserincore PRIVATE -Wall -Wextra)
# The module goes into the build folder, outside the shell's config folder: Quickshell serves that folder through
# its own copy, where a C++ plugin is not found.
set_target_properties(anserincore PROPERTIES LIBRARY_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/module")
configure_file(qmldir "${CMAKE_BINARY_DIR}/module/qmldir" COPYONLY)

# anserin-core, the helper program (no Qt): system usage, monitors, lock keys, backlight, Night light
pkg_check_modules(WAYLAND REQUIRED IMPORTED_TARGET wayland-client)
pkg_check_modules(SYSTEMD REQUIRED IMPORTED_TARGET libsystemd)
find_program(WAYLAND_SCANNER wayland-scanner REQUIRED)
set(GAMMA_XML "${CMAKE_CURRENT_SOURCE_DIR}/protocols/wlr-gamma-control-unstable-v1.xml")
set(GAMMA_GEN "${CMAKE_BINARY_DIR}/gen")
add_custom_command(
    OUTPUT "${GAMMA_GEN}/wlr-gamma-control-unstable-v1-client-protocol.h" "${GAMMA_GEN}/wlr-gamma-control-unstable-v1-protocol.c"
    COMMAND ${CMAKE_COMMAND} -E make_directory "${GAMMA_GEN}"
    COMMAND ${WAYLAND_SCANNER} client-header "${GAMMA_XML}" "${GAMMA_GEN}/wlr-gamma-control-unstable-v1-client-protocol.h"
    COMMAND ${WAYLAND_SCANNER} private-code "${GAMMA_XML}" "${GAMMA_GEN}/wlr-gamma-control-unstable-v1-protocol.c"
    DEPENDS "${GAMMA_XML}")
add_executable(anserin-core
    tool/main.cpp tool/common.cpp tool/sysinfo.cpp tool/monitors.cpp tool/locks.cpp tool/brightness.cpp tool/gamma.cpp
    "${GAMMA_GEN}/wlr-gamma-control-unstable-v1-protocol.c")
target_include_directories(anserin-core PRIVATE "${GAMMA_GEN}" tool)
target_link_libraries(anserin-core PRIVATE PkgConfig::WAYLAND PkgConfig::SYSTEMD)
target_compile_features(anserin-core PRIVATE cxx_std_17)
target_compile_options(anserin-core PRIVATE $<$<COMPILE_LANGUAGE:CXX>:-Wall -Wextra>)
set_target_properties(anserin-core PROPERTIES RUNTIME_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/bin")

# anserin-wallpaper (Qt, no GUI): the wallpaper index with thumbnails and video posters (see wallpaper/indexer.cpp)
find_package(Qt6 REQUIRED COMPONENTS Gui)
add_executable(anserin-wallpaper wallpaper/indexer.cpp)
target_link_libraries(anserin-wallpaper PRIVATE Qt6::Gui)
target_compile_features(anserin-wallpaper PRIVATE cxx_std_17)
target_compile_options(anserin-wallpaper PRIVATE -Wall -Wextra)
set_target_properties(anserin-wallpaper PROPERTIES RUNTIME_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/bin")
