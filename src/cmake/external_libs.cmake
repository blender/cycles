# SPDX-FileCopyrightText: 2011-2022 Blender Foundation
#
# SPDX-License-Identifier: Apache-2.0

###########################################################################
# Helper macros
###########################################################################

macro(_set_default variable value)
  if(NOT ${variable})
    set(${variable} ${value})
  endif()
endmacro()

###########################################################################
# External USD Detection
#
# Run first since it affects the C++ ABI and libraries choice.
###########################################################################

if(WITH_CYCLES_HYDRA_RENDER_DELEGATE OR WITH_CYCLES_USD)
  set(WITH_USD ON)
endif()

if(WITH_USD)
  if(HOUDINI_ROOT)
    find_package(USDHoudini)
  elseif(PXR_ROOT)
    find_package(USDPixar)
  endif()
endif()

###########################################################################
# Precompiled libraries detection
#
# Use precompiled libraries from Blender repository
###########################################################################

if(APPLE)
  if(CMAKE_OSX_ARCHITECTURES STREQUAL "x86_64")
    set(_cycles_lib_dir "${CMAKE_SOURCE_DIR}/lib/macos_x64")
  else()
    set(_cycles_lib_dir "${CMAKE_SOURCE_DIR}/lib/macos_arm64")
  endif()

  # Always use system zlib
  find_package(ZLIB REQUIRED)
elseif(WIN32)
  if(CMAKE_SYSTEM_PROCESSOR STREQUAL "ARM64")
    set(_cycles_lib_dir "${CMAKE_SOURCE_DIR}/lib/windows_arm64")
  else()
    set(_cycles_lib_dir "${CMAKE_SOURCE_DIR}/lib/windows_x64")
  endif()
else()
  # Path to a locally compiled libraries.
  if(CMAKE_SYSTEM_PROCESSOR STREQUAL "x86_64")
    set(_cycles_lib_dir "${CMAKE_SOURCE_DIR}/lib/linux_x64")
  elseif(CMAKE_SYSTEM_PROCESSOR STREQUAL "aarch64")
    set(_cycles_lib_dir "${CMAKE_SOURCE_DIR}/lib/linux_arm64")
  else()
    set(_cycles_lib_dir "${CMAKE_SOURCE_DIR}/lib/linux_${CMAKE_SYSTEM_PROCESSOR}")
  endif()

  if(CMAKE_COMPILER_IS_GNUCC AND
     CMAKE_C_COMPILER_VERSION VERSION_LESS 9.3)
    message(FATAL_ERROR "GCC version must be at least 9.3 for precompiled libraries, found ${CMAKE_C_COMPILER_VERSION}")
  endif()
endif()

if(EXISTS ${_cycles_lib_dir} AND WITH_LIBS_PRECOMPILED)
  message(STATUS "Using precompiled libraries at ${_cycles_lib_dir}")

  _set_default(ALEMBIC_ROOT_DIR "${_cycles_lib_dir}/alembic")
  _set_default(Boost_ROOT "${_cycles_lib_dir}/boost")
  _set_default(EMBREE_ROOT_DIR "${_cycles_lib_dir}/embree")
  _set_default(EPOXY_ROOT_DIR "${_cycles_lib_dir}/epoxy")
  _set_default(IMATH_ROOT_DIR "${_cycles_lib_dir}/imath")
  _set_default(GLEW_ROOT_DIR "${_cycles_lib_dir}/glew")
  _set_default(JPEG_ROOT "${_cycles_lib_dir}/jpeg")
  if(WIN32)
    _set_default(MATERIALX_ROOT_DIR "${_cycles_lib_dir}/MaterialX")
  else()
    _set_default(MATERIALX_ROOT_DIR "${_cycles_lib_dir}/materialx")
  endif()
  _set_default(NANOVDB_ROOT_DIR "${_cycles_lib_dir}/openvdb")
  _set_default(OPENCOLORIO_ROOT_DIR "${_cycles_lib_dir}/opencolorio")
  _set_default(OPENEXR_ROOT_DIR "${_cycles_lib_dir}/openexr")
  _set_default(OPENIMAGEDENOISE_ROOT_DIR "${_cycles_lib_dir}/openimagedenoise")
  _set_default(OPENIMAGEIO_ROOT_DIR "${_cycles_lib_dir}/openimageio")
  _set_default(OPENJPEG_ROOT_DIR "${_cycles_lib_dir}/openjpeg")
  _set_default(OPENSUBDIV_ROOT_DIR "${_cycles_lib_dir}/opensubdiv")
  _set_default(OPENVDB_ROOT_DIR "${_cycles_lib_dir}/openvdb")
  _set_default(OSL_ROOT_DIR "${_cycles_lib_dir}/osl")
  _set_default(PNG_ROOT "${_cycles_lib_dir}/png")
  _set_default(PUGIXML_ROOT_DIR "${_cycles_lib_dir}/pugixml")
  _set_default(PYTHON_ROOT_DIR "${_cycles_lib_dir}/python")
  _set_default(SSE2NEON_ROOT_DIR "${_cycles_lib_dir}/sse2neon")
  _set_default(TBB_ROOT_DIR "${_cycles_lib_dir}/tbb")
  _set_default(TIFF_ROOT "${_cycles_lib_dir}/tiff")
  _set_default(USD_ROOT_DIR "${_cycles_lib_dir}/usd")
  _set_default(WEBP_ROOT_DIR "${_cycles_lib_dir}/webp")
  _set_default(ZLIB_ROOT "${_cycles_lib_dir}/zlib")
  _set_default(ZSTD_ROOT_DIR "${_cycles_lib_dir}/zstd")
  if(WIN32)
    set(LEVEL_ZERO_ROOT_DIR ${_cycles_lib_dir}/level_zero)
  else()
    set(LEVEL_ZERO_ROOT_DIR ${_cycles_lib_dir}/level-zero)
  endif()
  _set_default(SYCL_ROOT_DIR "${_cycles_lib_dir}/dpcpp")

  # Look in all library directories by default, except mesa and dpcpp which
  # can conflict with OpenGL and compiler detection.
  file(GLOB _cycles_lib_subdirs ${_cycles_lib_dir}/*)
  list(REMOVE_ITEM _cycles_lib_subdirs ${_cycles_lib_dir}/mesa)
  list(REMOVE_ITEM _cycles_lib_subdirs ${_cycles_lib_dir}/dpcpp)
  set(CMAKE_PREFIX_PATH ${_cycles_lib_dir}/zlib ${_cycles_lib_subdirs})

  # Ignore system libraries
  set(CMAKE_IGNORE_PATH "${CMAKE_PLATFORM_IMPLICIT_LINK_DIRECTORIES};${CMAKE_SYSTEM_INCLUDE_PATH};${CMAKE_C_IMPLICIT_INCLUDE_DIRECTORIES};${CMAKE_CXX_IMPLICIT_INCLUDE_DIRECTORIES}")
else()
  if(NOT WITH_LIBS_PRECOMPILED)
    message(STATUS "Not using precompiled libraries")
  else()
    message(STATUS "No precompiled libraries found at ${_cycles_lib_dir}")
  endif()
  message(STATUS "Attempting to use system libraries instead")
  unset(_cycles_lib_dir)
endif()

# Gather precompiled shared libraries to install.
macro(add_bundled_libraries library_dir)
  if(DEFINED _cycles_lib_dir)
    set(_library_dir ${_cycles_lib_dir}/${library_dir})
    if(WIN32)
      file(GLOB _bundled_libs ${_library_dir}/*\.dll)
    elseif(APPLE)
      file(GLOB _bundled_libs ${_library_dir}/*\.dylib*)
    else()
      file(GLOB _bundled_libs ${_library_dir}/*\.so*)
    endif()

    list(APPEND PLATFORM_BUNDLED_LIBRARY_DIRS ${_library_dir})
    if(WIN32)
      foreach(_bundled_lib ${_bundled_libs})
        if((${_bundled_lib} MATCHES "_d.dll$") OR (${_bundled_lib} MATCHES "_debug.dll$"))
          list(APPEND PLATFORM_BUNDLED_LIBRARIES_DEBUG ${_bundled_lib})
        else()
          list(APPEND PLATFORM_BUNDLED_LIBRARIES_RELEASE ${_bundled_lib})
        endif()
      endforeach()
    else()
      list(APPEND PLATFORM_BUNDLED_LIBRARIES_RELEASE ${_bundled_libs})
      list(APPEND PLATFORM_BUNDLED_LIBRARIES_DEBUG ${_bundled_libs})
    endif()

    unset(_library_dir)
    unset(_bundled_libs)
    unset(_bundled_lib)
  endif()
endmacro()

###########################################################################
# USD
###########################################################################

if(WITH_USD)
  if(NOT HOUDINI_ROOT AND NOT PXR_ROOT)
    find_package(USD)
    add_bundled_libraries(usd/lib)
  endif()

  set_and_warn_library_found("USD" USD_FOUND WITH_USD)

  if(WIN32)
    set(PYTHON_VERSION 3.11)
    string(REPLACE "." "" PYTHON_VERSION_NO_DOTS ${PYTHON_VERSION})
    set(PYTHON_INCLUDE_DIRS ${PYTHON_ROOT_DIR}/${PYTHON_VERSION_NO_DOTS}/include)
    set(PYTHON_LIBRARIES
      optimized ${PYTHON_ROOT_DIR}/${PYTHON_VERSION_NO_DOTS}/libs/python${PYTHON_VERSION_NO_DOTS}.lib
      debug ${PYTHON_ROOT_DIR}/${PYTHON_VERSION_NO_DOTS}/libs/python${PYTHON_VERSION_NO_DOTS}_d.lib)
    link_directories(${PYTHON_ROOT_DIR}/${PYTHON_VERSION_NO_DOTS}/libs)
    if(NOT HOUDINI_ROOT AND NOT PXR_ROOT)
      add_bundled_libraries(python/${PYTHON_VERSION_NO_DOTS}/bin)
    endif()
  else()
    find_package(PythonLibsUnix REQUIRED)
  endif()
endif()

###########################################################################
# Zlib
###########################################################################

if(MSVC AND EXISTS ${_cycles_lib_dir})
  set(ZLIB_INCLUDE_DIRS ${_cycles_lib_dir}/zlib/include)
  set(ZLIB_LIBRARIES ${_cycles_lib_dir}/zlib/lib/libz_st.lib)
  set(ZLIB_INCLUDE_DIR ${_cycles_lib_dir}/zlib/include)
  set(ZLIB_LIBRARY ${_cycles_lib_dir}/zlib/lib/libz_st.lib)
  set(ZLIB_DIR ${_cycles_lib_dir}/zlib)
  set(ZLIB_FOUND ON)
elseif(NOT APPLE)
  find_package(ZLIB REQUIRED)
endif()

###########################################################################
# PThreads
###########################################################################

if(MSVC AND EXISTS ${_cycles_lib_dir})
  set(PTHREADS_LIBRARIES "${_cycles_lib_dir}/pthreads/lib/pthreadVC3.lib")
  include_directories("${_cycles_lib_dir}/pthreads/include")
else()
  set(CMAKE_THREAD_PREFER_PTHREAD TRUE)
  find_package(Threads REQUIRED)
  set(PTHREADS_LIBRARIES ${CMAKE_THREAD_LIBS_INIT})
endif()

###########################################################################
# OpenImageIO and image libraries
###########################################################################

if(MSVC AND EXISTS ${_cycles_lib_dir})
  set(OPENIMAGEIO_INCLUDE_DIR ${OPENIMAGEIO_ROOT_DIR}/include)
  set(OPENIMAGEIO_INCLUDE_DIRS ${OPENIMAGEIO_INCLUDE_DIR} ${OPENIMAGEIO_INCLUDE_DIR}/OpenImageIO)
  # Special exceptions for libraries which needs explicit debug version
  set(OPENIMAGEIO_LIBRARIES
    optimized ${OPENIMAGEIO_ROOT_DIR}/lib/OpenImageIO.lib
    optimized ${OPENIMAGEIO_ROOT_DIR}/lib/OpenImageIO_Util.lib
    debug ${OPENIMAGEIO_ROOT_DIR}/lib/OpenImageIO_d.lib
    debug ${OPENIMAGEIO_ROOT_DIR}/lib/OpenImageIO_Util_d.lib
  )

  set(PUGIXML_INCLUDE_DIR ${PUGIXML_ROOT_DIR}/include)
  set(PUGIXML_LIBRARIES
    optimized ${PUGIXML_ROOT_DIR}/lib/pugixml.lib
    debug ${PUGIXML_ROOT_DIR}/lib/pugixml_d.lib
  )
else()
  find_package(OpenImageIO REQUIRED)
  if(OPENIMAGEIO_PUGIXML_FOUND)
    set(PUGIXML_INCLUDE_DIR "${OPENIMAGEIO_INCLUDE_DIR}/OpenImageIO")
    set(PUGIXML_LIBRARIES "")
  else()
    find_package(PugiXML REQUIRED)
  endif()
endif()

# Dependencies
if(MSVC AND EXISTS ${_cycles_lib_dir})
  set(OPENJPEG_INCLUDE_DIR ${OPENJPEG}/include/openjpeg-2.3)
  set(OPENJPEG_LIBRARIES ${_cycles_lib_dir}/openjpeg/lib/openjp2${CMAKE_STATIC_LIBRARY_SUFFIX})
else()
  find_package(OpenJPEG REQUIRED)
endif()

find_package(JPEG REQUIRED)
find_package(TIFF REQUIRED)
find_package(WebP)

if(EXISTS ${_cycles_lib_dir})
  set(PNG_NAMES png16 libpng16 png libpng)
endif()
find_package(PNG REQUIRED)

if(WIN32)
  add_bundled_libraries(openimageio/bin)
else()
  add_bundled_libraries(openimageio/lib)
endif()

###########################################################################
# OpenEXR
###########################################################################

if(MSVC AND EXISTS ${_cycles_lib_dir})
  set(OPENEXR_INCLUDE_DIR ${OPENEXR_ROOT_DIR}/include)
  set(OPENEXR_INCLUDE_DIRS ${OPENEXR_INCLUDE_DIR} ${OPENEXR_ROOT_DIR}/include/OpenEXR ${IMATH_ROOT_DIR}/include ${IMATH_ROOT_DIR}/include/Imath)
  set(OPENEXR_LIBRARIES
    optimized ${OPENEXR_ROOT_DIR}/lib/OpenEXR.lib
    optimized ${OPENEXR_ROOT_DIR}/lib/OpenEXRCore.lib
    optimized ${OPENEXR_ROOT_DIR}/lib/Iex.lib
    optimized ${IMATH_ROOT_DIR}/lib/Imath.lib
    optimized ${OPENEXR_ROOT_DIR}/lib/IlmThread.lib
    debug ${OPENEXR_ROOT_DIR}/lib/OpenEXR_d.lib
    debug ${OPENEXR_ROOT_DIR}/lib/OpenEXRCore_d.lib
    debug ${OPENEXR_ROOT_DIR}/lib/Iex_d.lib
    debug ${IMATH_ROOT_DIR}/lib/Imath_d.lib
    debug ${OPENEXR_ROOT_DIR}/lib/IlmThread_d.lib
    )
else()
  find_package(OpenEXR REQUIRED)
endif()

if(WIN32)
	add_bundled_libraries(openexr/bin)
	add_bundled_libraries(imath/bin)
else()
	add_bundled_libraries(openexr/lib)
	add_bundled_libraries(imath/lib)
endif()

###########################################################################
# OpenShadingLanguage
###########################################################################

if(WITH_CYCLES_OSL)
	if(MSVC AND EXISTS ${_cycles_lib_dir})
		set(OSL_SHADER_DIR ${OSL_ROOT_DIR}/shaders)
		if(NOT EXISTS "${OSL_SHADER_DIR}")
			set(OSL_SHADER_DIR ${OSL_ROOT_DIR}/share/OSL/shaders)
		endif()
		find_library(OSL_LIB_EXEC NAMES oslexec PATHS ${OSL_ROOT_DIR}/lib)
		find_library(OSL_LIB_COMP NAMES oslcomp PATHS ${OSL_ROOT_DIR}/lib)
		find_library(OSL_LIB_QUERY NAMES oslquery PATHS ${OSL_ROOT_DIR}/lib)
		find_library(OSL_LIB_NOISE NAMES oslnoise PATHS ${OSL_ROOT_DIR}/lib)
		find_library(OSL_LIB_EXEC_DEBUG NAMES oslexec_d PATHS ${OSL_ROOT_DIR}/lib)
		find_library(OSL_LIB_COMP_DEBUG NAMES oslcomp_d PATHS ${OSL_ROOT_DIR}/lib)
		find_library(OSL_LIB_QUERY_DEBUG NAMES oslquery_d PATHS ${OSL_ROOT_DIR}/lib)
		find_library(OSL_LIB_NOISE_DEBUG NAMES oslnoise_d PATHS ${OSL_ROOT_DIR}/lib)
		list(APPEND OSL_LIBRARIES
			optimized ${OSL_LIB_COMP}
			optimized ${OSL_LIB_EXEC}
			optimized ${OSL_LIB_QUERY}
			debug ${OSL_LIB_EXEC_DEBUG}
			debug ${OSL_LIB_COMP_DEBUG}
			debug ${OSL_LIB_QUERY_DEBUG}
			${PUGIXML_LIBRARIES}
			)
		if(OSL_LIB_NOISE)
			list(APPEND OSL_LIBRARIES optimized ${OSL_LIB_NOISE})
		endif()
		if(OSL_LIB_NOISE_DEBUG)
			list(APPEND OSL_LIBRARIES debug ${OSL_LIB_NOISE_DEBUG})
		endif()
		find_path(OSL_INCLUDE_DIR OSL/oslclosure.h PATHS ${OSL_ROOT_DIR}/include)
		find_program(OSL_COMPILER NAMES oslc PATHS ${OSL_ROOT_DIR}/bin)
		file(STRINGS "${OSL_INCLUDE_DIR}/OSL/oslversion.h" OSL_LIBRARY_VERSION_MAJOR
		     REGEX "^[ \t]*#define[ \t]+OSL_LIBRARY_VERSION_MAJOR[ \t]+[0-9]+.*$")
		file(STRINGS "${OSL_INCLUDE_DIR}/OSL/oslversion.h" OSL_LIBRARY_VERSION_MINOR
		     REGEX "^[ \t]*#define[ \t]+OSL_LIBRARY_VERSION_MINOR[ \t]+[0-9]+.*$")
		file(STRINGS "${OSL_INCLUDE_DIR}/OSL/oslversion.h" OSL_LIBRARY_VERSION_PATCH
		     REGEX "^[ \t]*#define[ \t]+OSL_LIBRARY_VERSION_PATCH[ \t]+[0-9]+.*$")
		string(REGEX REPLACE ".*#define[ \t]+OSL_LIBRARY_VERSION_MAJOR[ \t]+([.0-9]+).*"
		       "\\1" OSL_LIBRARY_VERSION_MAJOR ${OSL_LIBRARY_VERSION_MAJOR})
		string(REGEX REPLACE ".*#define[ \t]+OSL_LIBRARY_VERSION_MINOR[ \t]+([.0-9]+).*"
		       "\\1" OSL_LIBRARY_VERSION_MINOR ${OSL_LIBRARY_VERSION_MINOR})
		string(REGEX REPLACE ".*#define[ \t]+OSL_LIBRARY_VERSION_PATCH[ \t]+([.0-9]+).*"
		       "\\1" OSL_LIBRARY_VERSION_PATCH ${OSL_LIBRARY_VERSION_PATCH})
	else()
		find_package(OSL REQUIRED)
	endif()
endif()

if(WIN32)
  add_bundled_libraries(osl/bin)
else()
  add_bundled_libraries(osl/lib)
endif()

###########################################################################
# OpenPGL
###########################################################################

if(WITH_CYCLES_PATH_GUIDING)
	if(NOT openpgl_DIR AND EXISTS ${_cycles_lib_dir})
		set(openpgl_DIR ${_cycles_lib_dir}/openpgl/lib/cmake/openpgl)
	endif()

	find_package(openpgl QUIET)
	if(openpgl_FOUND)
		if(WIN32)
			get_target_property(OPENPGL_LIBRARIES_RELEASE openpgl::openpgl LOCATION_RELEASE)
			get_target_property(OPENPGL_LIBRARIES_DEBUG openpgl::openpgl LOCATION_DEBUG)
			set(OPENPGL_LIBRARIES optimized ${OPENPGL_LIBRARIES_RELEASE} debug ${OPENPGL_LIBRARIES_DEBUG})
		else()
			get_target_property(OPENPGL_LIBRARIES openpgl::openpgl LOCATION)
		endif()
		get_target_property(OPENPGL_INCLUDE_DIR openpgl::openpgl INTERFACE_INCLUDE_DIRECTORIES)
	else()
		set_and_warn_library_found("OpenPGL" openpgl_FOUND WITH_CYCLES_PATH_GUIDING)
	endif()
endif()

###########################################################################
# OpenColorIO
###########################################################################

if(WITH_CYCLES_OPENCOLORIO)
	set(WITH_OPENCOLORIO ON)

	if(NOT USD_OVERRIDE_OPENCOLORIO)
		if(MSVC AND EXISTS ${_cycles_lib_dir})
			set(OPENCOLORIO_INCLUDE_DIRS ${OPENCOLORIO_ROOT_DIR}/include)
			set(OPENCOLORIO_LIBRARIES
				optimized ${OPENCOLORIO_ROOT_DIR}/lib/OpenColorIO.lib
				debug ${OPENCOLORIO_ROOT_DIR}/lib/OpencolorIO_d.lib
				)
		else()
			find_package(OpenColorIO REQUIRED)
		endif()
	endif()
endif()

if(WIN32)
	add_bundled_libraries(opencolorio/bin)
else()
	add_bundled_libraries(opencolorio/lib)
endif()

###########################################################################
# Boost
###########################################################################

if(EXISTS ${_cycles_lib_dir})
  if(MSVC)
    set(Boost_USE_STATIC_RUNTIME OFF)
    set(Boost_USE_MULTITHREADED ON)
  else()
    set(BOOST_LIBRARYDIR ${_cycles_lib_dir}/boost/lib)
    set(Boost_NO_BOOST_CMAKE ON)
    set(Boost_NO_SYSTEM_PATHS ON)
  endif()
endif()

if(MSVC AND EXISTS ${_cycles_lib_dir})
  set(BOOST_INCLUDE_DIR ${Boost_ROOT}/include)
  set(BOOST_VERSION_HEADER ${BOOST_INCLUDE_DIR}/boost/version.hpp)
  if(EXISTS ${BOOST_VERSION_HEADER})
    file(STRINGS "${BOOST_VERSION_HEADER}" BOOST_LIB_VERSION REGEX "#define BOOST_LIB_VERSION ")
    if(BOOST_LIB_VERSION MATCHES "#define BOOST_LIB_VERSION \"([0-9_]+)\"")
      set(BOOST_VERSION "${CMAKE_MATCH_1}")
    endif()
  endif()
  if(NOT BOOST_VERSION)
    message(FATAL_ERROR "Unable to determine Boost version")
  endif()
  if(CMAKE_SYSTEM_PROCESSOR STREQUAL "ARM64")
    set(BOOST_POSTFIX "vc143-mt-a64-${BOOST_VERSION}")
    set(BOOST_DEBUG_POSTFIX "vc143-mt-gyd-a64-${BOOST_VERSION}")
  else()
    set(BOOST_POSTFIX "vc142-mt-x64-${BOOST_VERSION}.lib")
    set(BOOST_DEBUG_POSTFIX "vc142-mt-gyd-x64-${BOOST_VERSION}.lib")
  endif()
  set(BOOST_LIBRARIES
    optimized ${Boost_ROOT}/lib/boost_date_time-${BOOST_POSTFIX}
    optimized ${Boost_ROOT}/lib/boost_iostreams-${BOOST_POSTFIX}
    optimized ${Boost_ROOT}/lib/boost_filesystem-${BOOST_POSTFIX}
    optimized ${Boost_ROOT}/lib/boost_regex-${BOOST_POSTFIX}
    optimized ${Boost_ROOT}/lib/boost_system-${BOOST_POSTFIX}
    optimized ${Boost_ROOT}/lib/boost_thread-${BOOST_POSTFIX}
    optimized ${Boost_ROOT}/lib/boost_chrono-${BOOST_POSTFIX}
    debug ${Boost_ROOT}/lib/boost_date_time-${BOOST_DEBUG_POSTFIX}
    debug ${Boost_ROOT}/lib/boost_iostreams-${BOOST_DEBUG_POSTFIX}
    debug ${Boost_ROOT}/lib/boost_filesystem-${BOOST_DEBUG_POSTFIX}
    debug ${Boost_ROOT}/lib/boost_regex-${BOOST_DEBUG_POSTFIX}
    debug ${Boost_ROOT}/lib/boost_system-${BOOST_DEBUG_POSTFIX}
    debug ${Boost_ROOT}/lib/boost_thread-${BOOST_DEBUG_POSTFIX}
    debug ${Boost_ROOT}/lib/boost_chrono-${BOOST_DEBUG_POSTFIX}
  )
  if(WITH_CYCLES_OSL)
    set(BOOST_LIBRARIES ${BOOST_LIBRARIES}
      optimized ${Boost_ROOT}/lib/boost_wave-${BOOST_POSTFIX}
      debug ${Boost_ROOT}/lib/boost_wave-${BOOST_DEBUG_POSTFIX})
  endif()
  if(WITH_USD)
    set(BOOST_LIBRARIES ${BOOST_LIBRARIES}
      optimized ${Boost_ROOT}/lib/boost_python${PYTHON_VERSION_NO_DOTS}-${BOOST_POSTFIX}
      debug ${Boost_ROOT}/lib/boost_python${PYTHON_VERSION_NO_DOTS}-${BOOST_DEBUG_POSTFIX})
  endif()
else()
  set(__boost_packages iostreams filesystem regex system thread date_time)
  if(WITH_CYCLES_OSL)
    list(APPEND __boost_packages wave)
  endif()
  if(WITH_USD)
    list(APPEND __boost_packages python${PYTHON_VERSION_NO_DOTS})
  endif()
  find_package(Boost 1.48 COMPONENTS ${__boost_packages} REQUIRED)
  if(NOT Boost_FOUND)
    # Try to find non-multithreaded if -mt not found, this flag
    # doesn't matter for us, it has nothing to do with thread
    # safety, but keep it to not disturb build setups.
    set(Boost_USE_MULTITHREADED OFF)
    find_package(Boost 1.48 COMPONENTS ${__boost_packages})
  endif()
  unset(__boost_packages)

  set(BOOST_INCLUDE_DIR ${Boost_INCLUDE_DIRS})
  set(BOOST_LIBRARIES ${Boost_LIBRARIES})
  set(BOOST_LIBPATH ${Boost_LIBRARY_DIRS})
endif()

set(BOOST_DEFINITIONS "-DBOOST_ALL_NO_LIB ${BOOST_DEFINITIONS}")

add_bundled_libraries(boost/lib)

###########################################################################
# Embree
###########################################################################

if(WITH_CYCLES_EMBREE)
  if(MSVC AND EXISTS ${_cycles_lib_dir})
    set(EMBREE_ROOT_DIR ${_cycles_lib_dir}/embree)
    set(EMBREE_INCLUDE_DIRS ${EMBREE_ROOT_DIR}/include)

    if(EXISTS ${EMBREE_ROOT_DIR}/include/embree4/rtcore_config.h)
      set(EMBREE_MAJOR_VERSION 4)
    else()
      set(EMBREE_MAJOR_VERSION 3)
    endif()

    file(READ ${EMBREE_ROOT_DIR}/include/embree${EMBREE_MAJOR_VERSION}/rtcore_config.h _embree_config_header)
    if(_embree_config_header MATCHES "#define EMBREE_STATIC_LIB")
      set(EMBREE_STATIC_LIB TRUE)
    else()
      set(EMBREE_STATIC_LIB FALSE)
    endif()

    if(_embree_config_header MATCHES "#define EMBREE_SYCL_SUPPORT")
      set(EMBREE_SYCL_SUPPORT TRUE)
    else()
      set(EMBREE_SYCL_SUPPORT FALSE)
    endif()

    set(EMBREE_LIBRARIES
      optimized ${EMBREE_ROOT_DIR}/lib/embree${EMBREE_MAJOR_VERSION}.lib
      debug ${EMBREE_ROOT_DIR}/lib/embree${EMBREE_MAJOR_VERSION}_d.lib
    )

    if(EMBREE_SYCL_SUPPORT)
      set(EMBREE_LIBRARIES
        ${EMBREE_LIBRARIES}
        optimized ${EMBREE_ROOT_DIR}/lib/embree4_sycl.lib
        debug ${EMBREE_ROOT_DIR}/lib/embree4_sycl_d.lib
      )
    endif()

    if(EMBREE_STATIC_LIB)
      set(EMBREE_LIBRARIES
        ${EMBREE_LIBRARIES}
        optimized ${EMBREE_ROOT_DIR}/lib/embree_avx2.lib
        optimized ${EMBREE_ROOT_DIR}/lib/embree_avx.lib
        optimized ${EMBREE_ROOT_DIR}/lib/embree_sse42.lib
        optimized ${EMBREE_ROOT_DIR}/lib/lexers.lib
        optimized ${EMBREE_ROOT_DIR}/lib/math.lib
        optimized ${EMBREE_ROOT_DIR}/lib/simd.lib
        optimized ${EMBREE_ROOT_DIR}/lib/sys.lib
        optimized ${EMBREE_ROOT_DIR}/lib/tasking.lib
        debug ${EMBREE_ROOT_DIR}/lib/embree_avx2_d.lib
        debug ${EMBREE_ROOT_DIR}/lib/embree_avx_d.lib
        debug ${EMBREE_ROOT_DIR}/lib/embree_sse42_d.lib
        debug ${EMBREE_ROOT_DIR}/lib/lexers_d.lib
        debug ${EMBREE_ROOT_DIR}/lib/math_d.lib
        debug ${EMBREE_ROOT_DIR}/lib/simd_d.lib
        debug ${EMBREE_ROOT_DIR}/lib/sys_d.lib
        debug ${EMBREE_ROOT_DIR}/lib/tasking_d.lib
      )

      if(EMBREE_SYCL_SUPPORT)
        set(EMBREE_LIBRARIES
          ${EMBREE_LIBRARIES}
          optimized ${EMBREE_ROOT_DIR}/lib/embree_rthwif.lib
          debug ${EMBREE_ROOT_DIR}/lib/embree_rthwif_d.lib
        )
      endif()
    endif()
  else()
    find_package(Embree 3.8.0 REQUIRED)
  endif()
endif()

if(WIN32)
  add_bundled_libraries(embree/bin)
else()
  add_bundled_libraries(embree/lib)
endif()

###########################################################################
# Logging
###########################################################################

if(WITH_CYCLES_LOGGING)
  find_package(Glog REQUIRED)
  find_package(Gflags REQUIRED)
endif()

###########################################################################
# OpenSubdiv
###########################################################################

if(WITH_CYCLES_OPENSUBDIV)
  set(WITH_OPENSUBDIV ON)

  if(NOT USD_OVERRIDE_OPENSUBDIV)
    if(MSVC AND EXISTS ${_cycles_lib_dir})
      set(OPENSUBDIV_INCLUDE_DIRS ${OPENSUBDIV_ROOT_DIR}/include)
      set(OPENSUBDIV_LIBRARIES
        optimized ${OPENSUBDIV_ROOT_DIR}/lib/osdCPU.lib
        optimized ${OPENSUBDIV_ROOT_DIR}/lib/osdGPU.lib
        debug ${OPENSUBDIV_ROOT_DIR}/lib/osdCPU_d.lib
        debug ${OPENSUBDIV_ROOT_DIR}/lib/osdGPU_d.lib
      )
    else()
      find_package(OpenSubdiv REQUIRED)
    endif()
  endif()
endif()

add_bundled_libraries(opensubdiv/lib)

###########################################################################
# OpenVDB
###########################################################################

if(WITH_CYCLES_OPENVDB)
  set(WITH_OPENVDB ON)

  if(NOT USD_OVERRIDE_OPENVDB)
    find_package(OpenVDB REQUIRED)
  endif()
endif()

if(WIN32)
  add_bundled_libraries(openvdb/bin)
else()
  add_bundled_libraries(openvdb/lib)
endif()

###########################################################################
# NanoVDB
###########################################################################

if(WITH_CYCLES_NANOVDB)
  set(WITH_NANOVDB ON)

  if(MSVC AND EXISTS ${_cycles_lib_dir})
    set(NANOVDB_INCLUDE_DIR ${NANOVDB_ROOT_DIR}/include)
    set(NANOVDB_INCLUDE_DIRS ${NANOVDB_INCLUDE_DIR})
  else()
    find_package(NanoVDB REQUIRED)
  endif()
endif()

###########################################################################
# OpenImageDenoise
###########################################################################

if(WITH_CYCLES_OPENIMAGEDENOISE)
  set(WITH_OPENIMAGEDENOISE ON)
  find_package(OpenImageDenoise REQUIRED)
endif()

if(WIN32)
  add_bundled_libraries(openimagedenoise/bin)
else()
  add_bundled_libraries(openimagedenoise/lib)
endif()

###########################################################################
# TBB
###########################################################################

if(NOT USD_OVERRIDE_TBB)
  if(MSVC AND EXISTS ${_cycles_lib_dir})
    set(TBB_INCLUDE_DIRS ${TBB_ROOT_DIR}/include)
    set(TBB_LIBRARIES
      optimized ${TBB_ROOT_DIR}/lib/tbb.lib
      debug ${TBB_ROOT_DIR}/lib/tbb_debug.lib
    )
  else()
    find_package(TBB REQUIRED)
  endif()
endif()

if(WIN32)
  add_bundled_libraries(tbb/bin)
else()
  add_bundled_libraries(tbb/lib)
endif()

###########################################################################
# Epoxy
###########################################################################

if((WITH_CYCLES_STANDALONE AND WITH_CYCLES_STANDALONE_GUI) OR
   WITH_CYCLES_HYDRA_RENDER_DELEGATE)
  if(MSVC AND EXISTS ${_cycles_lib_dir})
    set(Epoxy_LIBRARIES "${_cycles_lib_dir}/epoxy/lib/epoxy.lib")
    set(Epoxy_INCLUDE_DIRS "${_cycles_lib_dir}/epoxy/include")
  else()
    find_package(Epoxy REQUIRED)
  endif()
endif()

if(WIN32)
  add_bundled_libraries(epoxy/bin)
endif()

###########################################################################
# Alembic
###########################################################################

if(WITH_CYCLES_ALEMBIC)
  if(MSVC AND EXISTS ${_cycles_lib_dir})
    set(ALEMBIC_INCLUDE_DIRS ${_cycles_lib_dir}/alembic/include)
    set(ALEMBIC_LIBRARIES
      optimized ${_cycles_lib_dir}/alembic/lib/Alembic.lib
      debug ${_cycles_lib_dir}/alembic/lib/Alembic_d.lib)
  else()
    find_package(Alembic REQUIRED)
  endif()

  set(WITH_ALEMBIC ON)
endif()

###########################################################################
# MaterialX
###########################################################################

if(WIN32)
  add_bundled_libraries(MaterialX/bin)
else()
  add_bundled_libraries(materialx/lib)
endif()

if(WITH_USD)
  if(DEFINED _cycles_lib_dir)
    # USD linking needs to be able to find MaterialX libraries.
    link_directories(${MATERIALX_ROOT_DIR}/lib)

    if(UNIX AND NOT APPLE)
      find_package(MaterialX)
      list(APPEND USD_LIBRARIES
        MaterialXCore
        MaterialXFormat
        MaterialXRender
        MaterialXGenGlsl
        MaterialXGenMsl
      )
    endif()
  endif()
endif()

###########################################################################
# ZSTD
###########################################################################

if(WIN32 AND DEFINED _cycles_lib_dir)
  set(ZSTD_INCLUDE_DIRS ${ZSTD_ROOT_DIR}/include)
  set(ZSTD_LIBRARIES ${ZSTD_ROOT_DIR}/lib/zstd_static.lib)
else()
  find_package(Zstd REQUIRED)
endif()

###########################################################################
# SSE2NEON
###########################################################################

# Check for ARM Neon Support
if(NOT DEFINED SUPPORT_NEON_BUILD)
  include(CheckCXXSourceCompiles)
  check_cxx_source_compiles(
    "#include <arm_neon.h>
     int main() {return vaddvq_s32(vdupq_n_s32(1));}"
    SUPPORT_NEON_BUILD)
endif()

if(SUPPORT_NEON_BUILD)
  if(WIN32 AND DEFINED _cycles_lib_dir)
    set(SSE2NEON_INCLUDE_DIRS ${SSE2NEON_ROOT_DIR})
    set(SSE2NEON_FOUND True)
  else()
    find_package(sse2neon)
  endif()
endif()

###########################################################################
# System Libraries
###########################################################################

# Detect system libraries again
if(EXISTS ${_cycles_lib_dir})
  unset(CMAKE_IGNORE_PATH)
  unset(CMAKE_PREFIX_PATH)
  unset(_cycles_lib_dir)
endif()

###########################################################################
# SDL
###########################################################################

if(WITH_CYCLES_STANDALONE AND WITH_CYCLES_STANDALONE_GUI)
  # We can't use the version from the Blender precompiled libraries because
  # it does not include the video subsystem.
  find_package(SDL2 REQUIRED)
  set_and_warn_library_found("SDL" SDL2_FOUND WITH_CYCLES_STANDALONE_GUI)

  if(SDL2_FOUND)
    include_directories(
      SYSTEM
      ${SDL2_INCLUDE_DIRS}
    )
  endif()
endif()

###########################################################################
# CUDA
###########################################################################

if(WITH_CYCLES_DEVICE_CUDA AND (WITH_CYCLES_CUDA_BINARIES OR NOT WITH_CUDA_DYNLOAD))
  find_package(CUDA) # Try to auto locate CUDA toolkit
  set_and_warn_library_found("CUDA compiler" CUDA_FOUND WITH_CYCLES_CUDA_BINARIES)

  if(CUDA_FOUND)
    message(STATUS "Found CUDA ${CUDA_NVCC_EXECUTABLE} (${CUDA_VERSION})")
  else()
    if(NOT WITH_CUDA_DYNLOAD)
      message(STATUS "Additionally falling back to dynamic CUDA load")
      set(WITH_CUDA_DYNLOAD ON)
    endif()
  endif()
endif()

###########################################################################
# HIP
###########################################################################

if(WITH_CYCLES_DEVICE_HIP)
  if(WITH_CYCLES_HIP_BINARIES)
    # Need at least HIP 5.5 to solve compiler bug affecting the kernel.
    find_package(HIP 5.5.0)
    set_and_warn_library_found("HIP compiler" HIP_FOUND WITH_CYCLES_HIP_BINARIES)

    if(HIP_FOUND)
      message(STATUS "Found HIP ${HIP_HIPCC_EXECUTABLE} (${HIP_VERSION})")
    endif()
  endif()

  # HIP RT
  if(WITH_CYCLES_DEVICE_HIP AND WITH_CYCLES_DEVICE_HIPRT)
    find_package(HIPRT)
    set_and_warn_library_found("HIP RT" HIPRT_FOUND WITH_CYCLES_DEVICE_HIPRT)
  endif()
endif()

if(NOT WITH_CYCLES_DEVICE_HIP)
  set(WITH_CYCLES_DEVICE_HIPRT OFF)
endif()

if(NOT WITH_HIP_DYNLOAD)
  set(WITH_HIP_DYNLOAD ON)
endif()

###########################################################################
# Metal
###########################################################################

if(WITH_CYCLES_DEVICE_METAL)
  find_library(METAL_LIBRARY Metal)

  # This file was added in the 12.0 SDK, use it as a way to detect the version.
  if(METAL_LIBRARY)
    if(EXISTS "${METAL_LIBRARY}/Headers/MTLFunctionStitching.h")
      set(METAL_FOUND ON)
    else()
      message(STATUS "Metal version too old, must be SDK 12.0 or newer")
      set(METAL_FOUND OFF)
    endif()
  endif()

  set_and_warn_library_found("Metal" METAL_FOUND WITH_CYCLES_DEVICE_METAL)
  if(METAL_FOUND)
    message(STATUS "Found Metal: ${METAL_LIBRARY}")
  endif()
endif()

###########################################################################
# oneAPI
###########################################################################

if(WITH_CYCLES_DEVICE_ONEAPI OR EMBREE_SYCL_SUPPORT)
  # Find packages for even when WITH_CYCLES_DEVICE_ONEAPI is OFF, as it's
  # needed for linking to Embree with SYCL support.
  find_package(SYCL)
  find_package(LevelZero)

  if(WITH_CYCLES_DEVICE_ONEAPI)
    set_and_warn_library_found("oneAPI" SYCL_FOUND WITH_CYCLES_DEVICE_ONEAPI)
    set_and_warn_library_found("Level Zero" LEVEL_ZERO_FOUND WITH_CYCLES_DEVICE_ONEAPI)
    if(NOT (SYCL_FOUND AND SYCL_VERSION VERSION_GREATER_EQUAL 6.0 AND LEVEL_ZERO_FOUND))
      message(STATUS "SYCL 6.0+ or Level Zero not found, disabling WITH_CYCLES_DEVICE_ONEAPI")
      set(WITH_CYCLES_DEVICE_ONEAPI OFF)
    endif()
  endif()

  if(DEFINED SYCL_ROOT_DIR)
    if(WIN32)
      if(EXISTS ${SYCL_ROOT_DIR}/bin/sycl7.dll)
        list(APPEND PLATFORM_BUNDLED_LIBRARIES_RELEASE
          ${SYCL_ROOT_DIR}/bin/sycl7.dll
          ${SYCL_ROOT_DIR}/bin/pi_level_zero.dll
          ${SYCL_ROOT_DIR}/bin/pi_win_proxy_loader.dll)
        list(APPEND PLATFORM_BUNDLED_LIBRARIES_DEBUG
          ${SYCL_ROOT_DIR}/bin/sycl7d.dll
          ${SYCL_ROOT_DIR}/bin/pi_level_zero.dll
          ${SYCL_ROOT_DIR}/bin/pi_win_proxy_loaderd.dll)
      else()
        list(APPEND PLATFORM_BUNDLED_LIBRARIES_RELEASE
          ${SYCL_ROOT_DIR}/bin/sycl6.dll
          ${SYCL_ROOT_DIR}/bin/pi_level_zero.dll)
        list(APPEND PLATFORM_BUNDLED_LIBRARIES_DEBUG
          ${SYCL_ROOT_DIR}/bin/sycl6d.dll
          ${SYCL_ROOT_DIR}/bin/pi_level_zero.dll)
      endif()
    else()
      file(GLOB _sycl_runtime_libraries
        ${SYCL_ROOT_DIR}/lib/libsycl.so
        ${SYCL_ROOT_DIR}/lib/libsycl.so.*
        ${SYCL_ROOT_DIR}/lib/libpi_*.so
      )
      list(FILTER _sycl_runtime_libraries EXCLUDE REGEX ".*\.py")
      list(REMOVE_ITEM _sycl_runtime_libraries "${SYCL_ROOT_DIR}/lib/libpi_opencl.so")
      list(APPEND PLATFORM_BUNDLED_LIBRARIES_RELEASE ${_sycl_runtime_libraries})
      list(APPEND PLATFORM_BUNDLED_LIBRARIES_DEBUG ${_sycl_runtime_libraries})
      unset(_sycl_runtime_libraries)
  endif()
endif()

endif()

if(WITH_CYCLES_DEVICE_ONEAPI AND WITH_CYCLES_ONEAPI_BINARIES)
  if(NOT OCLOC_INSTALL_DIR)
    get_filename_component(_sycl_compiler_root ${SYCL_COMPILER} DIRECTORY)
    get_filename_component(OCLOC_INSTALL_DIR "${_sycl_compiler_root}/../lib/ocloc" ABSOLUTE)
    unset(_sycl_compiler_root)
  endif()

  if(NOT EXISTS ${OCLOC_INSTALL_DIR})
    set(OCLOC_FOUND OFF)
    message(STATUS "oneAPI ocloc not found in ${OCLOC_INSTALL_DIR}."
                   " A different ocloc directory can be set using OCLOC_INSTALL_DIR cmake variable.")
    set_and_warn_library_found("ocloc" OCLOC_FOUND WITH_CYCLES_ONEAPI_BINARIES)
  endif()
endif()

###########################################################################
# Bundled shared libraries
###########################################################################

if(WIN32)
  set(PLATFORM_LIB_INSTALL_DIR ".")
  # Environment variables to run precompiled executables that needed libraries.
  list(JOIN PLATFORM_BUNDLED_LIBRARY_DIRS "\;" _library_paths)
  set(PLATFORM_ENV_BUILD_DIRS "${_library_paths}\;${PATH}")
  set(PLATFORM_ENV_BUILD "PATH=${PLATFORM_ENV_BUILD_DIRS}")
  unset(_library_paths)

  # Bundle crt libraries
  set(CMAKE_INSTALL_SYSTEM_RUNTIME_LIBS_SKIP TRUE)
  set(CMAKE_INSTALL_UCRT_LIBRARIES TRUE)
  set(CMAKE_INSTALL_OPENMP_LIBRARIES FALSE)
  include(InstallRequiredSystemLibraries)
  install(FILES ${CMAKE_INSTALL_SYSTEM_RUNTIME_LIBS} DESTINATION . COMPONENT Libraries)
elseif(APPLE)
  set(PLATFORM_LIB_INSTALL_DIR "lib")
  # For install step, set rpath relative to where shared libs will be copied.
  set(CMAKE_SKIP_INSTALL_RPATH FALSE)
  list(APPEND CMAKE_INSTALL_RPATH "@loader_path/${PLATFORM_LIB_INSTALL_DIR}")

  # For build step, set absolute path to lib folder as it runs before install.
  set(CMAKE_SKIP_BUILD_RPATH FALSE)
  list(APPEND CMAKE_BUILD_RPATH ${PLATFORM_BUNDLED_LIBRARY_DIRS})

  # Environment variables to run precompiled executables that needed libraries.
  list(JOIN PLATFORM_BUNDLED_LIBRARY_DIRS ":" _library_paths)
  set(PLATFORM_ENV_BUILD "DYLD_LIBRARY_PATH=\"${_library_paths};${DYLD_LIBRARY_PATH}\"")
  unset(_library_paths)
elseif(UNIX)
  set(PLATFORM_LIB_INSTALL_DIR "lib")
  # For install step, set rpath relative to where shared libs will be copied.
  set(CMAKE_SKIP_INSTALL_RPATH FALSE)
  list(APPEND CMAKE_INSTALL_RPATH $ORIGIN/${PLATFORM_LIB_INSTALL_DIR})

  # For build step, set absolute path to lib folder as it runs before install.
  set(CMAKE_SKIP_BUILD_RPATH FALSE)
  list(APPEND CMAKE_BUILD_RPATH $ORIGIN/${PLATFORM_LIB_INSTALL_DIR} ${CMAKE_INSTALL_PREFIX_WITH_CONFIG}/${PLATFORM_LIB_INSTALL_DIR})

  # Environment variables to run precompiled executables that needed libraries.
  list(JOIN PLATFORM_BUNDLED_LIBRARY_DIRS ":" _library_paths)
  set(PLATFORM_ENV_BUILD "LD_LIBRARY_PATH=\"${_library_paths}:${LD_LIBRARY_PATH}\"")
  unset(_library_paths)
endif()
