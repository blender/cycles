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

  unset(_pxr_library_dir)
else()
  message(STATUS "Did not find USD at ${PXR_ROOT}")
endif()
