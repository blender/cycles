# - Find OpenSubdiv library
# Find the native OpenSubdiv includes and library
# This module defines
#  OPENSUBDIV_INCLUDE_DIR, where to find version.h, Set when
#                            OPENSUBDIV_INCLUDE_DIR is found.
#  OPENSUBDIV_LIBRARIES, libraries to link against to use OpenSubdiv.
#  OPENSUBDIV_ROOT_DIR, The base directory to search for OpenSubdiv.
#                        This can also be an environment variable.
#  OPENSUBDIV_FOUND, If false, do not try to use OpenSubdiv.
#

#=============================================================================
# Copyright 2011 Blender Foundation.
#
# Distributed under the OSI-approved BSD License (the "License");
# see accompanying file Copyright.txt for details.
#
# This software is distributed WITHOUT ANY WARRANTY; without even the
# implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
# See the License for more information.
#=============================================================================

# If OPENSUBDIV_ROOT_DIR was defined in the environment, use it.
IF(NOT OPENSUBDIV_ROOT_DIR AND NOT $ENV{OPENSUBDIV_ROOT_DIR} STREQUAL "")
  SET(OPENSUBDIV_ROOT_DIR $ENV{OPENSUBDIV_ROOT_DIR})
ENDIF()

SET(_opensubdiv_SEARCH_DIRS
  ${OPENSUBDIV_ROOT_DIR}
  /usr/local
  /sw # Fink
  /opt/local # DarwinPorts
  /opt/csw # Blastwave
  /opt/lib/osd
)

FIND_PATH(OPENSUBDIV_INCLUDE_DIR
  NAMES
    opensubdiv/version.h
  HINTS
    ${_opensubdiv_SEARCH_DIRS}
  PATH_SUFFIXES
    include
)

FIND_LIBRARY(OPENSUBDIV_LIBRARY
  NAMES
    osdCPU
  HINTS
    ${_opensubdiv_SEARCH_DIRS}
  PATH_SUFFIXES
    lib64 lib
  )

# handle the QUIETLY and REQUIRED arguments and set OPENSUBDIV_FOUND to TRUE if
# all listed variables are TRUE
INCLUDE(FindPackageHandleStandardArgs)
FIND_PACKAGE_HANDLE_STANDARD_ARGS(OpenSubdiv DEFAULT_MSG
    OPENSUBDIV_LIBRARY OPENSUBDIV_INCLUDE_DIR)

IF(OPENSUBDIV_FOUND)
  SET(OPENSUBDIV_LIBRARIES ${OPENSUBDIV_LIBRARY})
ENDIF()

MARK_AS_ADVANCED(
  OPENSUBDIV_INCLUDE_DIR
  OPENSUBDIV_LIBRARY
)
