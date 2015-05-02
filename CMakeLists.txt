cmake_minimum_required(VERSION 2.6)

set(PROJECT_NAME sqlite)
set(SQLITE_SRC_DIR ${CMAKE_CURRENT_SOURCE_DIR}/sqlite-src)
project(${PROJECT_NAME} C)

message("Building on: ${CMAKE_SYSTEM_NAME}")

#option(SQLITE_BUILD_STATIC  "Build SQLite static library" OFF)
option(SQLITE_BUILD_SHARED  "Build SQLite shared library" ON)
option(WITH_SQLITE_DEBUG    "Build SQLite debug features" OFF)
option(WITH_SQLITE_MEMDEBUG "Build SQLite memory debug features" OFF)
option(WITH_SQLITE_RTREE    "Build R*Tree index extension" ON)
option(WITH_SQLITE_FTS      "Build full text search extension" ON)

set(INSTALL_LIB_DIR "" CACHE PATH "Installation directory for libraries")
set(INSTALL_INC_DIR "" CACHE PATH "Installation directory for headers")

set(SQLITE_WIN_BUILD OFF)
set(SQLITE_LIN_BUILD OFF)
set(SQLITE_OSX_BUILD OFF)

if(${CMAKE_SYSTEM_NAME} MATCHES "Windows")
  set(SQLITE_WIN_BUILD ON)
  set(INSTALL_DIR "${CMAKE_CURRENT_SOURCE_DIR}/Windows-x64/")
endif()

if(${CMAKE_SYSTEM_NAME} MATCHES "Linux")
  set(SQLITE_LIN_BUILD ON)
  set(INSTALL_DIR "${CMAKE_CURRENT_SOURCE_DIR}/Linux-x64/")
endif()

if(${CMAKE_SYSTEM_NAME} MATCHES "OSX")
  set(SQLITE_OSX_BUILD ON)
  set(INSTALL_DIR "${CMAKE_CURRENT_SOURCE_DIR}/OSX-x64/")
endif()


# ---------------------
# Version detection
# ---------------------
file(STRINGS "${SQLITE_SRC_DIR}/sqlite3.h" _sqlite_api_h_VER_STRING REGEX ".*#define[ ]+SQLITE_VERSION[ ]+")

string(REGEX MATCH "[0-9\\.]+" SQLITE_VER_STRING ${_sqlite_api_h_VER_STRING})
string(REGEX MATCHALL "[0-9]+" _sqlite_ver_LIST "${SQLITE_VER_STRING}")
list(LENGTH _sqlite_ver_LIST _sqlite_list_len)
list(GET _sqlite_ver_LIST 0 SQLITE_VER_MAJOR)
list(GET _sqlite_ver_LIST 1 SQLITE_VER_MINOR)
list(GET _sqlite_ver_LIST 2 SQLITE_VER_PATCH)
if(_sqlite_list_len EQUAL 4)
  list(GET _sqlite_ver_LIST 3 SQLITE_VER_PATCHLEVEL)
  message("Patch level: ${SQLITE_VER_PATCHLEVEL}")
endif()

message("FOUND: SQLite version = ${SQLITE_VER_STRING}")

set(SQLITE_DYN_NAME "${PROJECT_NAME}${SQLITE_VER_MAJOR}")
#set(SQLITE_STATIC_NAME "${SQLITE_DYN_NAME}-static")

# add include path for project
include_directories(${SQLITE_SRC_DIR})

set(SRC_LIB_FILE ${SQLITE_SRC_DIR}/sqlite${SQLITE_VER_MAJOR}.c)
file(GLOB HDR_FILES ${SQLITE_SRC_DIR}/*.h)

# adding compilation flags depending on options
if(WITH_SQLITE_DEBUG)
  add_definitions(-DSQLITE_DEBUG)
endif()
if(WITH_SQLITE_MEMDEBUG)
  add_definitions(-DSQLITE_MEMDEBUG)
endif()
if(WITH_SQLITE_RTREE)
  add_definitions(-DSQLITE_ENABLE_RTREE)
endif()
if(WITH_SQLITE_FTS)
  add_definitions(-DSQLITE_ENABLE_FTS4)
endif()

add_definitions(-std=c99)
add_definitions(-O2)

#if (SQLITE_BUILD_STATIC)
## build static library
#add_library(${SQLITE_STATIC_NAME} STATIC ${SRC_LIB_FILE})
#endif()

if (SQLITE_BUILD_SHARED)
  # build dynamic library
  add_library(${SQLITE_DYN_NAME} SHARED ${SRC_LIB_FILE})
  if (SQLITE_WIN_BUILD)
    #then we do dll library, so need to export api
    set_target_properties(${SQLITE_DYN_NAME} PROPERTIES DEFINE_SYMBOL "SQLITE_API=__declspec(dllexport)")
  endif()
endif()

message("Installing shared lib to: ${INSTALL_DIR}")

install(TARGETS ${SQLITE_DYN_NAME} LIBRARY DESTINATION "${INSTALL_DIR}")
install(FILES $HDR_FILES DESTINATION "${INSTALL_DIR}")

