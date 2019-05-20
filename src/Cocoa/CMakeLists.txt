# 3.14 for Xcode 10.2 support
cmake_minimum_required(VERSION 3.14)

if(NOT ${CMAKE_GENERATOR} STREQUAL "Xcode")
    message( FATAL_ERROR "CMAKE_GENERATOR not Xcode." )
endif()


if(NOT DEFINED ENV{FRAMEWORKS_ARCH_PATHS})
    message( FATAL_ERROR "FRAMEWORKS_ARCH_PATHS not Defined." )
endif()

# read and set env vars
set(CMAKE_Swift_LANGUAGE_VERSION 5.0)
set(CMAKE_BUILD_TYPE $ENV{CONFIGURATION})
set(MACOS_SDK_PATH $ENV{SDKROOT})

set(COCOA 1)
add_definitions(-DCOCOA)

set(DEF_CONF ${CMAKE_SOURCE_DIR}/CMake.xcconfig)
set(DEF_TEMPLATE ${DEF_CONF}.template)

set(TOP_DIRECTORY ${CMAKE_SOURCE_DIR}/../..)
# set(BUILD_DIRECTORY ./build)

list(APPEND CMAKE_MODULE_PATH "${TOP_DIRECTORY}/cmake")

include(SetBuildType)
include(ReadCurrentBuild)
include(TimeStamps)

project(libsoftether VERSION ${CurrentBuild_VERSION} LANGUAGES C)


set(CMAKE_CONFIGURATION_TYPES "Debug;Release" CACHE STRING "" FORCE)

# Xcode Project Global Settings 
set(CMAKE_OSX_SYSROOT "$(PLATFORM_NAME)")
set(CMAKE_XCODE_ATTRIBUTE_MACH_O_TYPE staticlib)
set(CMAKE_OSX_DEPLOYMENT_TARGET "$(MACOSX_DEPLOYMENT_TARGET)")
set(CMAKE_IPHONEOS_DEPLOYMENT_TARGET "$(IPHONEOS_DEPLOYMENT_TARGET)")
set(CMAKE_XCODE_ATTRIBUTE_VALID_ARCHS $ENV{VALID_ARCHS})
set(CMAKE_XCODE_ATTRIBUTE_SUPPORTED_PLATFORMS "iphonesimulator iphoneos macosx")
set(CMAKE_XCODE_ATTRIBUTE_GENERATE_MASTER_OBJECT_FILE YES) 
set(CMAKE_XCODE_ATTRIBUTE_ALWAYS_SEARCH_USER_PATHS NO)
set(CMAKE_XCODE_ATTRIBUTE_USE_HEADERMAP YES)

add_subdirectory(.. src)

# Export CMake Configurations to Xcode
get_directory_property(defs DIRECTORY ../Cedar COMPILE_DEFINITIONS)
string(REPLACE ";" " " defs_spaces "${defs}")

get_directory_property(includes DIRECTORY ../Cedar INCLUDE_DIRECTORIES)
string(REPLACE ";" " " includes_spaces "${includes}")

configure_file(${DEF_TEMPLATE} ${DEF_CONF})
