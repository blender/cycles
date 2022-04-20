# Copyright 2011-2020 Blender Foundation
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

macro(ADD_CHECK_CXX_COMPILER_FLAG
  _CXXFLAGS
  _CACHE_VAR
  _FLAG)

  include(CheckCXXCompilerFlag)

  CHECK_CXX_COMPILER_FLAG("${_FLAG}" "${_CACHE_VAR}")
  if(${_CACHE_VAR})
    # message(STATUS "Using CXXFLAG: ${_FLAG}")
    set(${_CXXFLAGS} "${${_CXXFLAGS}} ${_FLAG}")
  else()
    message(STATUS "Unsupported CXXFLAG: ${_FLAG}")
  endif()
endmacro()

# pair of macros to allow libraries to be specify files to install, but to
# only install them at the end so the directories don't get cleared with
# the files in them. used by cycles to install addon.
macro(delayed_install
  base
  files
  destination)

  foreach(f ${files})
    if(IS_ABSOLUTE ${f} OR "${base}" STREQUAL "")
      set_property(GLOBAL APPEND PROPERTY DELAYED_INSTALL_FILES ${f})
    else()
      set_property(GLOBAL APPEND PROPERTY DELAYED_INSTALL_FILES ${base}/${f})
    endif()
    set_property(GLOBAL APPEND PROPERTY DELAYED_INSTALL_DESTINATIONS ${destination})
  endforeach()
endmacro()

# note this is a function instead of a macro so that ${BUILD_TYPE} in targetdir
# does not get expanded in calling but is preserved
function(delayed_do_install)

  get_property(files GLOBAL PROPERTY DELAYED_INSTALL_FILES)
  get_property(destinations GLOBAL PROPERTY DELAYED_INSTALL_DESTINATIONS)

  if(files)
    list(LENGTH files n)
    math(EXPR n "${n}-1")

    foreach(i RANGE ${n})
      list(GET files ${i} f)
      list(GET destinations ${i} d)
      install(FILES ${f} DESTINATION ${d})
    endforeach()
  endif()
endfunction()

macro(remove_cc_flag
        flag)

  string(REGEX REPLACE ${flag} "" CMAKE_C_FLAGS "${CMAKE_C_FLAGS}")
  string(REGEX REPLACE ${flag} "" CMAKE_C_FLAGS_DEBUG "${CMAKE_C_FLAGS_DEBUG}")
  string(REGEX REPLACE ${flag} "" CMAKE_C_FLAGS_RELEASE "${CMAKE_C_FLAGS_RELEASE}")
  string(REGEX REPLACE ${flag} "" CMAKE_C_FLAGS_MINSIZEREL "${CMAKE_C_FLAGS_MINSIZEREL}")
  string(REGEX REPLACE ${flag} "" CMAKE_C_FLAGS_RELWITHDEBINFO "${CMAKE_C_FLAGS_RELWITHDEBINFO}")

  string(REGEX REPLACE ${flag} "" CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS}")
  string(REGEX REPLACE ${flag} "" CMAKE_CXX_FLAGS_DEBUG "${CMAKE_CXX_FLAGS_DEBUG}")
  string(REGEX REPLACE ${flag} "" CMAKE_CXX_FLAGS_RELEASE "${CMAKE_CXX_FLAGS_RELEASE}")
  string(REGEX REPLACE ${flag} "" CMAKE_CXX_FLAGS_MINSIZEREL "${CMAKE_CXX_FLAGS_MINSIZEREL}")
  string(REGEX REPLACE ${flag} "" CMAKE_CXX_FLAGS_RELWITHDEBINFO "${CMAKE_CXX_FLAGS_RELWITHDEBINFO}")

endmacro()

macro(remove_extra_strict_flags)
  if(CMAKE_COMPILER_IS_GNUCC)
    remove_cc_flag("-Wunused-parameter")
  endif()

  if(CMAKE_C_COMPILER_ID MATCHES "Clang")
    remove_cc_flag("-Wunused-parameter")
  endif()

  if(MSVC)
    # TODO
  endif()
endmacro()
