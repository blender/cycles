# SPDX-License-Identifier: BSD-3-Clause
# Copyright 2019 Blender Foundation.

# Find Hydra, TBB, OpenSubdiv and OpenVDB in a USD installation.
# Variables are matching those output by FindUSDHoudini.cmake.

find_package(pxr CONFIG REQUIRED PATHS ${PXR_ROOT} NO_DEFAULT_PATH)

if(pxr_FOUND)
  message(STATUS "Found USD: ${PXR_CMAKE_DIR}")
  set(USD_FOUND ON)
  set(_pxr_library_dir ${PXR_CMAKE_DIR}/lib)

  # USD
  set(USD_INCLUDE_DIRS ${PXR_INCLUDE_DIRS})
  set(USD_LIBRARIES hd hgi hgiGL usd usdImaging usdGeom)

  # OpenSubdiv
  find_library(_opensubdiv_library_cpu_debug_pxr NAMES osdCPU_d osdCPU PATHS ${_pxr_library_dir} NO_DEFAULT_PATH)
  find_library(_opensubdiv_library_gpu_debug_pxr NAMES osdGPU_d osdGPU PATHS ${_pxr_library_dir} NO_DEFAULT_PATH)
  find_library(_opensubdiv_library_cpu_release_pxr NAMES osdCPU PATHS ${_pxr_library_dir} NO_DEFAULT_PATH)
  find_library(_opensubdiv_library_gpu_release_pxr NAMES osdGPU PATHS ${_pxr_library_dir} NO_DEFAULT_PATH)
  if(_opensubdiv_library_cpu_release_pxr AND _opensubdiv_library_gpu_release_pxr)
    set(OPENSUBDIV_INCLUDE_DIRS ${PXR_INCLUDE_DIRS})
    set(OPENSUBDIV_LIBRARIES
      optimized ${_opensubdiv_library_cpu_release_pxr}
      optimized ${_opensubdiv_library_gpu_release_pxr}
      debug ${_opensubdiv_library_cpu_debug_pxr}
      debug ${_opensubdiv_library_gpu_debug_pxr}
    )
    set(USD_OVERRIDE_OPENSUBDIV ON)
  endif()
  unset(_opensubdiv_library_cpu_debug_pxr CACHE)
  unset(_opensubdiv_library_gpu_debug_pxr CACHE)
  unset(_opensubdiv_library_cpu_release_pxr CACHE)
  unset(_opensubdiv_library_gpu_release_pxr CACHE)

  # OpenVDB
  find_library(_openvdb_library_pxr NAMES openvdb PATHS ${_pxr_library_dir} NO_DEFAULT_PATH)
  if(_openvdb_library_pxr)
    set(OPENVDB_INCLUDE_DIRS ${PXR_INCLUDE_DIRS})
    set(OPENVDB_LIBRARIES ${_openvdb_library_pxr})
    set(USD_OVERRIDE_OPENVDB ON)
  endif()
  unset(_openvdb_library_pxr CACHE)

  # TBB
  find_library(_tbb_library_debug_pxr NAMES tbb_debug tbb PATHS ${_pxr_library_dir} NO_DEFAULT_PATH)
  find_library(_tbb_library_release_pxr NAMES tbb PATHS ${_pxr_library_dir} NO_DEFAULT_PATH)
  if(_tbb_library_release_pxr)
    set(TBB_INCLUDE_DIRS ${PXR_INCLUDE_DIRS})
    set(TBB_LIBRARIES
      optimized ${_tbb_library_release_pxr}
      debug ${_tbb_library_debug_pxr}
    )
    set(USD_OVERRIDE_TBB ON)
  endif()
  unset(_tbb_library_debug_pxr CACHE)
  unset(_tbb_library_release_pxr CACHE)

  # OpenColorIO
  find_library(_opencolorio_library_pxr NAMES OpenColorIO PATHS ${_pxr_library_dir} NO_DEFAULT_PATH)
  if(_opencolorio_library_pxr)
    add_library(OpenColorIO::OpenColorIO UNKNOWN IMPORTED)
    set_target_properties(OpenColorIO::OpenColorIO PROPERTIES
      IMPORTED_LOCATION "${_opencolorio_library_pxr}"
      INTERFACE_INCLUDE_DIRECTORIES "${PXR_INCLUDE_DIRS}"
    )
    set(USD_OVERRIDE_OPENCOLORIO ON)
  endif()
  unset(_opencolorio_library_pxr CACHE)

  # OpenEXR
  find_library(_openexr_library_pxr NAMES OpenEXR OpenCore PATHS ${_pxr_library_dir} NO_DEFAULT_PATH)
  if(_openexr_library_pxr)
    add_library(OpenEXR::OpenEXR UNKNOWN IMPORTED)
    set_target_properties(OpenEXR::OpenEXR PROPERTIES
      IMPORTED_LOCATION "${_openexr_library_pxr}"
      INTERFACE_INCLUDE_DIRECTORIES "${PXR_INCLUDE_DIRS}"
    )
    set(USD_OVERRIDE_OPENEXR ON)
  endif()
  unset(_openexr_library_pxr CACHE)

  # OpenImageIO
  find_library(_openimageio_library_pxr NAMES OpenImageIO PATHS ${_pxr_library_dir} NO_DEFAULT_PATH)
  find_library(_openimageio_util_library_pxr NAMES OpenImageIO_Util PATHS ${_pxr_library_dir} NO_DEFAULT_PATH)
  if(_openimageio_library_pxr AND _openimageio_util_library_pxr)
    add_library(OpenImageIO::OpenImageIO UNKNOWN IMPORTED)
    set_target_properties(OpenImageIO::OpenImageIO PROPERTIES
      IMPORTED_LOCATION "${_openimageio_library_pxr}"
      INTERFACE_LINK_LIBRARIES "${_openimageio_util_library_pxr}"
      INTERFACE_INCLUDE_DIRECTORIES "${PXR_INCLUDE_DIRS}"
    )
    set(USD_OVERRIDE_OPENIMAGEIO ON)
  endif()
  unset(_openimageio_library_pxr CACHE)

  # MaterialX
  find_library(_materialx_core_library_pxr NAMES MaterialXCore PATHS ${_pxr_library_dir} NO_DEFAULT_PATH)
  if(_materialx_core_library_pxr)
    list(APPEND USD_LIBRARIES
      MaterialXCore
      MaterialXFormat
      MaterialXRender
      MaterialXGenGlsl
      MaterialXGenMsl
    )
  endif()
  set(USD_OVERRIDE_MATERIALX ON)

  message(STATUS "OSL is not part of the USD package, disabling WITH_CYCLES_OSL")
  set(WITH_CYCLES_OSL OFF)
  message(STATUS "NanoVDB is not part of the USD package, disabling WITH_CYCLES_NANOVDB")
  set(WITH_CYCLES_NANOVDB OFF)

  unset(_pxr_library_dir)
else()
  message(STATUS "Did not find USD at ${PXR_ROOT}")
endif()
