# SPDX-FileCopyrightText: 2021 Blender Authors
#
# SPDX-License-Identifier: BSD-3-Clause

# Find HIPRT SDK. This module defines:
#   HIPRT_INCLUDE_DIR, path to HIPRT include directory
#   HIPRT_FOUND, if SDK found

if(NOT (DEFINED HIPRT_ROOT_DIR))
  set(HIPRT_ROOT_DIR "")
endif()

# If `HIPRT_ROOT_DIR` was defined in the environment, use it.
if(HIPRT_ROOT_DIR)
  # Pass.
elseif(DEFINED ENV{HIPRT_ROOT_DIR})
  set(HIPRT_ROOT_DIR $ENV{HIPRT_ROOT_DIR})
elseif(DEFINED ENV{HIP_PATH})
  # Built-in environment variable from SDK.
  set(HIPRT_ROOT_DIR $ENV{HIP_PATH})
endif()

set(_hiprt_SEARCH_DIRS
  ${HIPRT_ROOT_DIR}
  /opt/lib/hiprt
)

find_path(HIPRT_INCLUDE_DIR
  NAMES
    hiprt/hiprt.h
  HINTS
    ${_hiprt_SEARCH_DIRS}
  PATH_SUFFIXES
    include
)

unset(_hiprt_version)
include(FindPackageHandleStandardArgs)
find_package_handle_standard_args(HIPRT DEFAULT_MSG
  HIPRT_INCLUDE_DIR)

mark_as_advanced(
  HIPRT_INCLUDE_DIR
)

unset(_hiprt_SEARCH_DIRS)
