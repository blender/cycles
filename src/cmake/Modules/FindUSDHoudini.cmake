# SPDX-License-Identifier: BSD-3-Clause
# Copyright 2019 Blender Foundation.

# Find USD libraries in Houdini installation.
# Variables are matching those output by FindUSDPixar.cmake.

if(HOUDINI_ROOT AND EXISTS ${HOUDINI_ROOT})
  message(STATUS "Found Houdini: ${HOUDINI_ROOT}")

  set(USD_FOUND ON)

  # Houdini paths
  if(WIN32)
    set(_library_dir ${HOUDINI_ROOT}/custom/houdini/dsolib)
    set(_include_dir ${HOUDINI_ROOT}/toolkit/include)
    list(APPEND CMAKE_FIND_LIBRARY_PREFIXES lib "")
  elseif(APPLE)
    set(_library_dir ${HOUDINI_ROOT}/Frameworks/Houdini.framework/Libraries)
    set(_include_dir ${HOUDINI_ROOT}/Frameworks/Houdini.framework/Resources/toolkit/include)
  elseif(UNIX)
    set(_library_dir ${HOUDINI_ROOT}/dsolib)
    set(_include_dir ${HOUDINI_ROOT}/toolkit/include)
  endif()

  # USD
  set(USD_LIBRARIES hd hgi hgiGL gf arch garch plug tf trace vt work sdf cameraUtil hf pxOsd usd usdImaging usdGeom)

  foreach(lib ${USD_LIBRARIES})
    find_library(_pxr_library NAMES pxr_${lib} PATHS ${_library_dir} NO_DEFAULT_PATH)
    add_library(${lib} SHARED IMPORTED)
    set_property(TARGET ${lib} APPEND PROPERTY IMPORTED_CONFIGURATIONS RELEASE)
    get_filename_component(_pxr_soname ${_pxr_library} NAME)
    set_target_properties(${lib} PROPERTIES
      IMPORTED_LOCATION_RELEASE "${_pxr_library}"
      IMPORTED_SONAME_RELEASE "${_pxr_soname}"
      IMPORTED_IMPLIB_RELEASE "${_pxr_library}"
    )
    unset(_pxr_library CACHE)
    unset(_pxr_soname)
  endforeach()

  # Python
  find_path(_python_include_dir NAMES "pyconfig.h" PATHS ${_include_dir}/* NO_DEFAULT_PATH)
  get_filename_component(_python_name ${_python_include_dir} NAME)
  string(REGEX REPLACE "python([0-9]+)\.([0-9]+)[m]?" "\\1" _python_major ${_python_name})
  string(REGEX REPLACE "python([0-9]+)\.([0-9]+)[m]?" "\\2" _python_minor ${_python_name})

  if(WIN32)
    set(_python_library_dir ${HOUDINI_ROOT}/python${_python_major}${_python_minor}/libs)
  elseif(APPLE)
    set(_python_library_dir ${HOUDINI_ROOT}/Frameworks/Python.framework/Versions/Current/lib)
  elseif(UNIX)
    set(_python_library_dir ${HOUDINI_ROOT}/python/lib)
  endif()

  find_library(_python_library
    NAMES
      python${_python_major}${_python_minor}
      python${_python_major}.${_python_minor}
      python${_python_major}.${_python_minor}m
    PATHS
      ${_python_library_dir}
    NO_DEFAULT_PATH)

  find_library(_boost_python_library
    NAMES
      hboost_python-mt
      hboost_python${_python_major}${_python_minor}
      hboost_python${_python_major}${_python_minor}-mt-x64
    PATHS
      ${_library_dir}
    NO_DEFAULT_PATH)

  set(USD_INCLUDE_DIR ${_include_dir})
  list(APPEND USD_INCLUDE_DIRS ${_python_include_dir})
  list(APPEND USD_LIBRARIES ${_python_library} ${_boost_python_library})

  unset(_python_name)
  unset(_python_major)
  unset(_python_minor)
  unset(_python_library_dir)
  unset(_python_include_dir CACHE)
  unset(_python_library CACHE)
  unset(_boost_python_library CACHE)

  # Boost
  set(BOOST_DEFINITIONS "-DHBOOST_ALL_NO_LIB")

  # OpenSubdiv
  find_library(_opensubdiv_library_cpu NAMES osdCPU osdCPU_md PATHS ${_library_dir} NO_DEFAULT_PATH)
  find_library(_opensubdiv_library_gpu NAMES osdGPU osdGPU_md PATHS ${_library_dir} NO_DEFAULT_PATH)
  set(OPENSUBDIV_INCLUDE_DIRS ${_include_dir})
  set(OPENSUBDIV_LIBRARIES
    ${_opensubdiv_library_cpu}
    ${_opensubdiv_library_gpu}
  )
  set(USD_OVERRIDE_OPENSUBDIV ON)
  unset(_opensubdiv_library_cpu CACHE)
  unset(_opensubdiv_library_gpu CACHE)

  # OpenVDB
  find_library(_openvdb_library NAMES openvdb_sesi PATHS ${_library_dir} NO_DEFAULT_PATH)
  set(OPENVDB_INCLUDE_DIRS ${_include_dir})
  set(OPENVDB_LIBRARIES ${_openvdb_library})
  set(USD_OVERRIDE_OPENVDB ON)
  unset(_openvdb_library CACHE)

  # TBB
  find_library(_tbb_library NAMES tbb PATHS ${_library_dir} NO_DEFAULT_PATH)
  set(TBB_INCLUDE_DIRS ${_include_dir})
  set(TBB_LIBRARIES ${_tbb_library})
  set(USD_OVERRIDE_TBB ON)
  unset(_tbb_library CACHE)

  # OpenColorIO
  find_library(_opencolorio_library NAMES OpenColorIO_sidefx PATHS ${_library_dir} NO_DEFAULT_PATH)
  set(OPENCOLORIO_INCLUDE_DIRS ${_include_dir})
  set(OPENCOLORIO_LIBRARIES ${_opencolorio_library})
  set(USD_OVERRIDE_OPENCOLORIO ON)
  unset(_opencolorio_library CACHE)

  # Cleanup
  unset(_library_dir)
  unset(_include_dir)
else()
  message(STATUS "Did not find Houdini at ${HOUDINI_ROOT}")
endif()
