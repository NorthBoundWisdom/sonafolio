# Consume a local GeoControls checkout. configs/qt_workflow.py config prepares the pinned
# copy; CMake itself never downloads sources.

set(GEOCONTROLS_SOURCE_ROOT "$ENV{GEOCONTROLS_SOURCE_ROOT}" CACHE PATH "Required local GeoControls checkout")
set(GEOCONTROLS_BUILD_DEMO OFF CACHE BOOL "Only build the reusable controls" FORCE)
set(GEOCONTROLS_INSTALL_SDK OFF CACHE BOOL "Consume GeoControls from its source root" FORCE)

if(NOT GEOCONTROLS_SOURCE_ROOT)
    message(FATAL_ERROR
        "GEOCONTROLS_SOURCE_ROOT is not set. Run `python3 configs/qt_workflow.py config` to "
        "prepare the pinned checkout, or set it to a local GeoControls checkout."
    )
endif()
get_filename_component(GEOCONTROLS_SOURCE_ROOT "${GEOCONTROLS_SOURCE_ROOT}" ABSOLUTE
    BASE_DIR "${CMAKE_CURRENT_LIST_DIR}/../../..")
foreach(required CMakeLists.txt Controls/CMakeLists.txt AppShell/CMakeLists.txt LICENSE)
    if(NOT EXISTS "${GEOCONTROLS_SOURCE_ROOT}/${required}")
        message(FATAL_ERROR "GEOCONTROLS_SOURCE_ROOT is missing ${required}. Run "
            "`python3 configs/qt_workflow.py config` to prepare the pinned checkout.")
    endif()
endforeach()
add_subdirectory("${GEOCONTROLS_SOURCE_ROOT}" "${CMAKE_CURRENT_BINARY_DIR}/_deps/geocontrols")
set(SONAFOLIO_GEOCONTROLS_SOURCE_ROOT "${GEOCONTROLS_SOURCE_ROOT}" CACHE INTERNAL "Resolved GeoControls source" FORCE)

add_library(GeoControls::Controls ALIAS GeoControlsControls)
add_library(GeoControls::AppShell ALIAS GeoControlsAppShell)
