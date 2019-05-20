# We define a dedicated variable because CMAKE_BUILD_TYPE can have different
# configurations than "Debug" and "Release", such as "RelWithDebInfo".
if(CMAKE_BUILD_TYPE STREQUAL "Debug")
  set(BUILD_TYPE "Debug")
else()
  set(BUILD_TYPE "Release")
endif()