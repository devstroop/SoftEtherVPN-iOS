file(GLOB SOURCES_MAYAQUA "*.c")
file(GLOB HEADERS_MAYAQUA "*.h")

if(COCOA)
  enable_language(Swift)
  file(GLOB SOURCES_MAYAQUA_SWIFT "*.swift")
endif()

if(WIN32)
  add_library(mayaqua STATIC ${SOURCES_MAYAQUA} ${HEADERS_MAYAQUA})
else()
  add_library(mayaqua SHARED ${SOURCES_MAYAQUA} ${SOURCES_MAYAQUA_SWIFT} ${HEADERS_MAYAQUA})
endif()

target_include_directories(mayaqua PUBLIC .)

set_target_properties(mayaqua
  PROPERTIES
  ARCHIVE_OUTPUT_DIRECTORY "${BUILD_DIRECTORY}"
  LIBRARY_OUTPUT_DIRECTORY "${BUILD_DIRECTORY}"
  RUNTIME_OUTPUT_DIRECTORY "${BUILD_DIRECTORY}"
)

if(WIN32)
  set_target_properties(mayaqua
    PROPERTIES
    COMPILE_PDB_NAME "mayaqua"
    COMPILE_PDB_OUTPUT_DIRECTORY "${BUILD_DIRECTORY}"
  )

  add_subdirectory(3rdparty/zlib)

  target_include_directories(mayaqua PRIVATE win32_inc)
  target_include_directories(mayaqua PRIVATE 3rdparty/zlib)

  if(${COMPILER_ARCHITECTURE} STREQUAL "x64")
    find_library(LIB_SSL
      NAMES libssl ssleay32
      HINTS "${TOP_DIRECTORY}/src/BuildFiles/Library/vs2017/x64_${BUILD_TYPE}"
    )

    find_library(LIB_CRYPTO
      NAMES libcrypto libeay32
      HINTS "${TOP_DIRECTORY}/src/BuildFiles/Library/vs2017/x64_${BUILD_TYPE}"
    )
  else()
    find_library(LIB_SSL
      NAMES libssl ssleay32
      HINTS "${TOP_DIRECTORY}/src/BuildFiles/Library/vs2017/Win32_${BUILD_TYPE}"
    )

    find_library(LIB_CRYPTO
      NAMES libcrypto libeay32
      HINTS "${TOP_DIRECTORY}/src/BuildFiles/Library/vs2017/Win32_${BUILD_TYPE}"
    )
  endif()

  target_link_libraries(mayaqua PRIVATE zlibstatic ${LIB_SSL} ${LIB_CRYPTO})
endif()

if(COCOA)
  set_target_properties(mayaqua PROPERTIES
    FRAMEWORK TRUE
    MACOSX_FRAMEWORK_IDENTIFIER "$ENV{APP_ID}.mayaqua"
    PUBLIC_HEADER "${HEADERS_MAYAQUA}"
    OUTPUT_NAME "Mayaqua"
    XCODE_ATTRIBUTE_SWIFT_OBJC_BRIDGING_HEADER "${CMAKE_CURRENT_SOURCE_DIR}/${OBJ_BRIDGE_NAME}"
    XCODE_ATTRIBUTE_FRAMEWORK_SEARCH_PATHS "$ENV{FRAMEWORKS_ARCH_PATHS}/$(PLATFORM_NAME)"
  )

  target_link_libraries(mayaqua PRIVATE "-lz -liconv -lreadline -framework openssl")

  add_definitions(-DSKIP_CPU_FEATURES)
elseif(UNIX)
  find_package(OpenSSL REQUIRED)
  find_package(Threads REQUIRED)
  find_package(ZLIB REQUIRED)

  # In some cases libiconv is not included in libc
  find_library(LIB_ICONV iconv HINTS /opt/local/lib)

  find_library(LIB_RT rt)
  target_link_libraries(mayaqua PRIVATE OpenSSL::SSL OpenSSL::Crypto Threads::Threads ZLIB::ZLIB)

  if(HAVE_SYS_AUXV)
    add_subdirectory(3rdparty/cpu_features)
    set_property(TARGET cpu_features PROPERTY POSITION_INDEPENDENT_CODE ON)
    target_link_libraries(mayaqua PRIVATE cpu_features)
  else()
    add_definitions(-DSKIP_CPU_FEATURES)
  endif()

  if(LIB_RT)
    target_link_libraries(mayaqua PRIVATE rt)
  endif()

  if(LIB_ICONV)
    target_link_libraries(mayaqua PRIVATE ${LIB_ICONV})
  endif()

  if(${CMAKE_SYSTEM_NAME} STREQUAL "SunOS")
    target_link_libraries(mayaqua PRIVATE nsl socket)
  endif()

  install(TARGETS mayaqua
    COMPONENT "common"
    DESTINATION "${CMAKE_INSTALL_LIBDIR}"
    PERMISSIONS OWNER_READ OWNER_WRITE OWNER_EXECUTE GROUP_READ GROUP_EXECUTE WORLD_READ WORLD_EXECUTE
  )
endif()
