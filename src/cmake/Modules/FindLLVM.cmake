# - Find LLVM library
# Find the native LLVM includes and library
# This module defines
#  LLVM_INCLUDE_DIRS, where to find LLVM headers, Set when
#                     LLVM_INCLUDE_DIR is found.
#  LLVM_LIBRARIES, libraries to link against to use OpenSubdiv.
#  LLVM_ROOT_DIR, the base directory to search for OpenSubdiv.
#                 This can also be an environment variable.
#  LLVM_CONFIG, full path to a llvm-config binary.
#  LLVM_VERSION, the version of found LLVM library
#  LLVM_FOUND, if false, do not try to use LLVM.
#
#=============================================================================
# Copyright 2014 Blender Foundation.
#
# Distributed under the OSI-approved BSD License (the "License");
# see accompanying file Copyright.txt for details.
#
# This software is distributed WITHOUT ANY WARRANTY; without even the
# implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
# See the License for more information.
#=============================================================================

IF(LLVM_ROOT_DIR)
  FIND_PROGRAM(LLVM_CONFIG llvm-config-${LLVM_VERSION}
               HINTS ${LLVM_ROOT_DIR}/bin
               NO_CMAKE_PATH NO_DEFAULT_PATH)
  IF(NOT LLVM_CONFIG)
    FIND_PROGRAM(LLVM_CONFIG llvm-config
                 HINTS ${LLVM_ROOT_DIR}/bin
                 NO_CMAKE_PATH)
  ENDIF()
ELSE()
  FIND_PROGRAM(LLVM_CONFIG llvm-config)
  IF(NOT LLVM_CONFIG)
    FOREACH(_llvm_VERSION 3.5 3.4 3.3 3.1 3.0)
      FIND_PROGRAM(LLVM_CONFIG llvm-config-${_llvm_VERSION})
      IF(LLVM_CONFIG)
        BREAK()
      ENDIF()
    ENDFOREACH()
  UNSET(_llvm_VERSION)
  ENDIF()
ENDIF()

IF(NOT DEFINED LLVM_VERSION)
  EXECUTE_PROCESS(COMMAND ${LLVM_CONFIG} --version
                  OUTPUT_VARIABLE LLVM_VERSION
                  OUTPUT_STRIP_TRAILING_WHITESPACE)
  SET(LLVM_VERSION ${LLVM_VERSION} CACHE STRING "Version of LLVM to use")
ENDIF()

IF(NOT DEFINED LLVM_ROOT_DIR)
  EXECUTE_PROCESS(COMMAND ${LLVM_CONFIG} --prefix
                  OUTPUT_VARIABLE LLVM_ROOT_DIR
                  OUTPUT_STRIP_TRAILING_WHITESPACE)
  SET(LLVM_ROOT_DIR ${LLVM_ROOT_DIR} CACHE PATH "Path to the LLVM installation")
ENDIF()

IF(NOT DEFINED LLVM_LIBPATH)
  EXECUTE_PROCESS(COMMAND ${LLVM_CONFIG} --libdir
                  OUTPUT_VARIABLE LLVM_LIBPATH
                  OUTPUT_STRIP_TRAILING_WHITESPACE)
  SET(LLVM_LIBPATH ${LLVM_LIBPATH} CACHE PATH "Path to the LLVM library")
  MARK_AS_ADVANCED(LLVM_LIBPATH)
ENDIF()

IF(NOT DEFINED LLVM_INCLUDE_DIRS)
  EXECUTE_PROCESS(COMMAND ${LLVM_CONFIG} --includedir
                  OUTPUT_VARIABLE LLVM_INCLUDE_DIRS
                  OUTPUT_STRIP_TRAILING_WHITESPACE)
  SET(LLVM_INCLUDE_DIRS ${LLVM_INCLUDE_DIRS} CACHE PATH "Path to the LLVM includes")
  MARK_AS_ADVANCED(LLVM_INCLUDE_DIRS)
ENDIF()

IF(LLVM_STATIC)
  FIND_LIBRARY(LLVM_LIBRARIES
               NAMES LLVMAnalysis # first of a whole bunch of libs to get
               PATHS ${LLVM_LIBPATH})
ELSE()
  FIND_LIBRARY(LLVM_LIBRARIES
               NAMES LLVM-${LLVM_VERSION}
               PATHS ${LLVM_LIBPATH})
ENDIF()

IF(LLVM_LIBRARIES AND LLVM_ROOT_DIR AND LLVM_LIBPATH)
  IF(LLVM_STATIC)
    EXECUTE_PROCESS(COMMAND ${LLVM_CONFIG} --libfiles
                    OUTPUT_VARIABLE LLVM_LIBRARIES
                    OUTPUT_STRIP_TRAILING_WHITESPACE)
    STRING(REPLACE " " ";" LLVM_LIBRARIES "${LLVM_LIBRARIES}")
  ENDIF()
ENDIF()

INCLUDE(FindPackageHandleStandardArgs)
FIND_PACKAGE_HANDLE_STANDARD_ARGS(LLVM DEFAULT_MSG
  LLVM_LIBRARIES LLVM_LIBPATH LLVM_ROOT_DIR)
