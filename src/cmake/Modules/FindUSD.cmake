# SPDX-License-Identifier: BSD-3-Clause
# Copyright 2019 Blender Foundation.

# Find Blender's Universal Scene Description (USD) library
# Variables are matching those output by FindUSDPixar.cmake.
# If USD_ROOT_DIR was defined in the environment, use it.
IF(NOT USD_ROOT_DIR AND NOT $ENV{USD_ROOT_DIR} STREQUAL "")
  SET(USD_ROOT_DIR $ENV{USD_ROOT_DIR})
ENDIF()

SET(_usd_SEARCH_DIRS
  ${USD_ROOT_DIR}
  /opt/lib/usd
)

FIND_PATH(USD_INCLUDE_DIR
  NAMES
    pxr/imaging/hd/renderDelegate.h
  HINTS
    ${_usd_SEARCH_DIRS}
  PATH_SUFFIXES
    include
  DOC "Universal Scene Description (USD) header files"
)

# Since USD 21.11 the libraries are prefixed with "usd_", i.e. "libusd_m.a" became "libusd_usd_m.a".
# See https://github.com/PixarAnimationStudios/USD/blob/release/CHANGELOG.md#2111---2021-11-01
FIND_LIBRARY(USD_LIBRARY
  NAMES
    usd_usd_m usd_usd_ms usd_m usd_ms
    ${PXR_LIB_PREFIX}usd
  NAMES_PER_DIR
  HINTS
    ${_usd_SEARCH_DIRS}
  PATH_SUFFIXES
    lib64 lib lib/static
  DOC "Universal Scene Description (USD) monolithic library"
)

IF(${USD_LIBRARY_NOTFOUND})
  set(USD_FOUND FALSE)
ELSE()
  # handle the QUIETLY and REQUIRED arguments and set USD_FOUND to TRUE if
  # all listed variables are TRUE
  INCLUDE(FindPackageHandleStandardArgs)
  FIND_PACKAGE_HANDLE_STANDARD_ARGS(USD DEFAULT_MSG USD_LIBRARY USD_INCLUDE_DIR)

  IF(USD_FOUND)
    get_filename_component(USD_LIBRARY_DIR ${USD_LIBRARY} DIRECTORY)
    SET(USD_INCLUDE_DIRS ${USD_INCLUDE_DIR})
    # Flags required by USD to avoid dropping static initializers for plugins.
    if(WIN32)
      set(USD_LIBRARIES "${USD_LIBRARY}")
    elseif(APPLE)
      set(USD_LIBRARIES "-Wl,-force_load ${USD_LIBRARY}")
    else()
      set(USD_LIBRARIES "-Wl,--whole-archive ${USD_LIBRARY} -Wl,--no-whole-archive")
    endif()
  ENDIF()
ENDIF()

MARK_AS_ADVANCED(
  USD_INCLUDE_DIR
  USD_LIBRARY_DIR
)

UNSET(_usd_SEARCH_DIRS)
