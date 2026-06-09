# SPDX-License-Identifier: BSD-3-Clause
# Copyright 2019 Blender Foundation.

# Find USD libraries in Houdini installation.
# Variables are matching those output by FindUSDPixar.cmake.

if(HOUDINI_ROOT AND EXISTS ${HOUDINI_ROOT})
  message(STATUS "Found Houdini: ${HOUDINI_ROOT}")

  set(USD_FOUND ON)
  set(HOUDINI_FOUND ON)
  
  # Houdini paths
  if(WIN32)
    set(_bin_dir ${HOUDINI_ROOT}/bin)
    set(_library_dir ${HOUDINI_ROOT}/custom/houdini/dsolib)
    set(_include_dir ${HOUDINI_ROOT}/toolkit/include)
    list(APPEND CMAKE_FIND_LIBRARY_PREFIXES lib "")
  elseif(APPLE)
    set(_library_dir ${HOUDINI_ROOT}/Frameworks/Houdini.framework/Libraries)
    set(_include_dir ${HOUDINI_ROOT}/Frameworks/Houdini.framework/Resources/toolkit/include)
  elseif(UNIX)
    set(_bin_dir ${HOUDINI_ROOT}/bin)
    set(_library_dir ${HOUDINI_ROOT}/dsolib)
    set(_include_dir ${HOUDINI_ROOT}/toolkit/include)
  endif()

  # Version and ABI
  file(STRINGS "${_include_dir}/HAPI/HAPI_Version.h" _houdini_version_major
    REGEX "^#define HAPI_VERSION_HOUDINI_MAJOR[ \t].*$")
  string(REGEX MATCHALL "[0-9]+" HOUDINI_VERSION_MAJOR ${_houdini_version_major})

  # USD
  set(USD_LIBRARIES hd hgi hgiGL gf arch garch plug tf trace vt work sdf cameraUtil hf pxOsd usd usdImaging usdGeom python)

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

  message(STATUS "Houdini Python version: ${_python_major}.${_python_minor}")

  set(USD_INCLUDE_DIR ${_include_dir})
  list(APPEND USD_INCLUDE_DIRS ${_python_include_dir})
  list(APPEND USD_LIBRARIES ${_python_library} ${_boost_python_library})

  set(USD_OVERRIDE_PYTHON ON)

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
  if(_opensubdiv_library_cpu AND _opensubdiv_library_gpu)
    set(OPENSUBDIV_INCLUDE_DIRS ${_include_dir})
    set(OPENSUBDIV_LIBRARIES
      ${_opensubdiv_library_cpu}
      ${_opensubdiv_library_gpu}
    )
    set(USD_OVERRIDE_OPENSUBDIV ON)
  endif()
  unset(_opensubdiv_library_cpu CACHE)
  unset(_opensubdiv_library_gpu CACHE)

  # OpenVDB
  find_library(_openvdb_library NAMES openvdb_sesi PATHS ${_library_dir} NO_DEFAULT_PATH)
  if(_openvdb_library)
    set(OPENVDB_INCLUDE_DIRS ${_include_dir})
    set(OPENVDB_LIBRARIES ${_openvdb_library})
    set(NANOVDB_INCLUDE_DIRS ${_include_dir})
    set(USD_OVERRIDE_OPENVDB ON)
    set(USD_OVERRIDE_NANOVDB ON)
  endif()
  unset(_openvdb_library CACHE)

  # TBB
  if (WIN32)
    find_library(_tbb_library NAMES tbb12 PATHS ${_library_dir} NO_DEFAULT_PATH)
  else()
    find_library(_tbb_library NAMES tbb PATHS ${_library_dir} NO_DEFAULT_PATH)
  endif()
  if(_tbb_library)
    set(TBB_INCLUDE_DIRS ${_include_dir})
    set(TBB_LIBRARIES ${_tbb_library})
    set(USD_OVERRIDE_TBB ON)
  endif()
  unset(_tbb_library CACHE)

  # OpenColorIO
  find_library(_opencolorio_library NAMES OpenColorIO_sidefx PATHS ${_library_dir} NO_DEFAULT_PATH)
  if(_opencolorio_library)
    add_library(OpenColorIO::OpenColorIO UNKNOWN IMPORTED)
    set_target_properties(OpenColorIO::OpenColorIO PROPERTIES
      IMPORTED_LOCATION "${_opencolorio_library}"
      INTERFACE_INCLUDE_DIRECTORIES "${_include_dir}"
    )
    set(USD_OVERRIDE_OPENCOLORIO ON)
  endif()
  unset(_opencolorio_library CACHE)

  # OpenEXR
  find_library(_openexr_library NAMES OpenEXR_sidefx PATHS ${_library_dir} NO_DEFAULT_PATH)
  if(_openexr_library)
    add_library(OpenEXR::OpenEXR SHARED IMPORTED)
    set_target_properties(OpenEXR::OpenEXR PROPERTIES
      IMPORTED_LOCATION "${_openexr_library}"
      IMPORTED_IMPLIB "${_openexr_library}"
      INTERFACE_INCLUDE_DIRECTORIES "${_include_dir}"
    )
    set(USD_OVERRIDE_OPENEXR ON)
  endif()
  unset(_openexr_library CACHE)

  # OpenImageIO
  find_library(_openimageio_library NAMES OpenImageIO_sidefx PATHS ${_library_dir} NO_DEFAULT_PATH)
  find_library(_openimageio_util_library NAMES OpenImageIO_Util_sidefx PATHS ${_library_dir} NO_DEFAULT_PATH)
  if(_openimageio_library AND _openimageio_util_library)
    add_library(OpenImageIO::OpenImageIO_Util UNKNOWN IMPORTED)  
    set_target_properties(OpenImageIO::OpenImageIO_Util PROPERTIES
        IMPORTED_LOCATION "${_openimageio_util_library}"
        IMPORTED_IMPLIB "${_openimageio_util_library}"
        INTERFACE_INCLUDE_DIRECTORIES "${_include_dir}"
      )  
    add_library(OpenImageIO::OpenImageIO UNKNOWN IMPORTED)
    set_target_properties(OpenImageIO::OpenImageIO PROPERTIES
      IMPORTED_LOCATION "${_openimageio_library}"
      INTERFACE_LINK_LIBRARIES "${_openimageio_util_library}"
      INTERFACE_INCLUDE_DIRECTORIES "${_include_dir}"
    )

    set(USD_OVERRIDE_OPENIMAGEIO ON)
  endif()
  unset(_openimageio_library CACHE)
  unset(_openimageio_util_library CACHE)

  # OSL
  find_library(_osl_library NAMES HOSL PATHS ${_library_dir} NO_DEFAULT_PATH)
  if(_osl_library)
    set(OSL_INCLUDE_DIRS ${_include_dir})
    set(OSL_LIBRARIES ${_osl_library})
    set(USD_OVERRIDE_OSL ON)
    set(WITH_CYCLES_OSL OFF)
  endif()
  unset(_osl_library CACHE)
  # We currently disable OSL support whne building hdCycles gainst Houdini
  set(WITH_CYCLES_OSL OFF)

  # MaterialX
  find_library(_materialx_core_library NAMES MaterialXCore  PATHS ${_library_dir} NO_DEFAULT_PATH)
  find_library(_materialx_format_library NAMES MaterialXFormat PATHS ${_library_dir} NO_DEFAULT_PATH)
  find_library(_materialx_render_library NAMES MaterialXRender PATHS ${_library_dir} NO_DEFAULT_PATH)
  find_library(_materialx_genglsl_library NAMES MaterialXGenGlsl PATHS ${_library_dir} NO_DEFAULT_PATH)
  find_library(_materialx_genmsl_library NAMES MaterialXGenMsl PATHS ${_library_dir} NO_DEFAULT_PATH)
  if(_materialx_core_library AND _materialx_format_library AND _materialx_render_library AND 
    _materialx_genglsl_library AND _materialx_genmsl_library)
    list(APPEND USD_LIBRARIES
      ${_materialx_library}
      ${_materialx_format_library}
      ${_materialx_render_library}
      ${_materialx_genglsl_library}
      ${_materialx_genmsl_library}
    )
    set(USD_OVERRIDE_MATERIALX ON)
  endif()
  unset(_materialx_library CACHE)

  # Cleanup
  unset(_library_dir)
  unset(_include_dir)
  unset(_bin_dir)
else()
  message(SEND_ERROR "Did not find Houdini at ${HOUDINI_ROOT}")
endif()
