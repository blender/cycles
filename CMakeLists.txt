###########################################################################
# Disable insource build

if(${CMAKE_SOURCE_DIR} STREQUAL ${CMAKE_BINARY_DIR})
	message(FATAL_ERROR
		"CMake generation for Cycles is not allowed within the source directory!"
		"\n Remove the CMakeCache.txt file and try again from another folder, e.g.:"
		"\n "
		"\n rm CMakeCache.txt"
		"\n cd .."
		"\n mkdir cmake-make"
		"\n cd cmake-make"
		"\n cmake ../cycles"
	)
endif()

###########################################################################
# Policies

cmake_minimum_required(VERSION 3.10)

# So library linking is more sane.
cmake_policy(SET CMP0003 NEW)

# So syntax problems are errors.
cmake_policy(SET CMP0010 NEW)

# So BUILDINFO and BLENDERPATH strings are automatically quoted.
cmake_policy(SET CMP0005 NEW)

# Input directories must have CMakeLists.txt
cmake_policy(SET CMP0014 NEW)

# Compile definitions.
cmake_policy(SET CMP0043 NEW)

# Use ROOT variables in find_package.
cmake_policy(SET CMP0074 NEW)
cmake_policy(SET CMP0144 NEW)

# Avoid having empty buildtype.
set(CMAKE_BUILD_TYPE_INIT "Release")

###########################################################################
# Initialize project.

project(Cycles)

###########################################################################
# Macros and utilities.

list(APPEND CMAKE_MODULE_PATH
	"${PROJECT_SOURCE_DIR}/src/cmake"
	"${PROJECT_SOURCE_DIR}/src/cmake/Modules"
)

include(compiler_utils)
include(macros)

###########################################################################
# Global settings.

set(CMAKE_INSTALL_MESSAGE LAZY)

if(CMAKE_INSTALL_PREFIX_INITIALIZED_TO_DEFAULT)
  set(CMAKE_INSTALL_PREFIX "${PROJECT_SOURCE_DIR}/install" CACHE PATH "Installation path" FORCE)
endif()

# Effective install path including config folder, as a generator expression.
get_property(GENERATOR_IS_MULTI_CONFIG GLOBAL PROPERTY GENERATOR_IS_MULTI_CONFIG)
if(GENERATOR_IS_MULTI_CONFIG)
  string(REPLACE "\${BUILD_TYPE}" "$<CONFIG>" CMAKE_INSTALL_PREFIX_WITH_CONFIG ${CMAKE_INSTALL_PREFIX})
else()
  string(REPLACE "\${BUILD_TYPE}" "" CMAKE_INSTALL_PREFIX_WITH_CONFIG ${CMAKE_INSTALL_PREFIX})
endif()

# Some stuff is different when building stabdalone Cycles from inside
# Blender source code and when building it from it's own repository.
set(CYCLES_STANDALONE_REPOSITORY TRUE)

# Force standalone build.
set(WITH_CYCLES_STANDALONE TRUE)

# Global compile definitions since add_definitions() adds for all.
set_property(DIRECTORY APPEND PROPERTY COMPILE_DEFINITIONS
  $<$<CONFIG:Debug>:DEBUG;_DEBUG>
  $<$<CONFIG:Release>:NDEBUG>
  $<$<CONFIG:MinSizeRel>:NDEBUG>
  $<$<CONFIG:RelWithDebInfo>:NDEBUG>
)

###########################################################################
# Options.

# Use precompiled library dependencies
option(WITH_LIBS_PRECOMPILED        "Use precompiled library dependencies" ON)

# Library dependencies
option(WITH_CYCLES_ALEMBIC          "Build with Alembic procedural support" ON)
option(WITH_CYCLES_EMBREE           "Build with Embree support" ON)
option(WITH_CYCLES_LOGGING          "Build with logging support (using glog)" OFF)
option(WITH_CYCLES_OPENCOLORIO      "Build with OpenColorIO support" ON)
option(WITH_CYCLES_OPENIMAGEDENOISE "Build with OpenImageDenoise support" ON)
option(WITH_CYCLES_OPENSUBDIV       "Build with OpenSubdiv support" ON)
option(WITH_CYCLES_OPENVDB          "Build with OpenVDB support" ON)
option(WITH_CYCLES_NANOVDB          "Build with NanoVDB support" ON)
option(WITH_CYCLES_OSL              "Build with OSL support" ON)
option(WITH_CYCLES_USD              "Build with USD support" ON)

if(UNIX AND NOT APPLE)
  option(WITH_CXX11_ABI              "Build with glibc C++11 ABI. Turn off for compatibility with VFX platform 2022 and earlier." ON)
endif()

# Development Features
option(WITH_CYCLES_DEBUG             "Build Cycles with options useful for debugging (e.g., MIS)" OFF)
option(WITH_CYCLES_DEBUG_NAN         "Build Cycles with additional asserts for detecting NaNs and invalid values" OFF)
option(WITH_CYCLES_NATIVE_ONLY       "Build Cycles with native kernel only (which fits current CPU, use for development only)" OFF)
option(WITH_CYCLES_STANDALONE_GUI    "Build Cycles standalone with GUI" OFF)

# NVIDIA CUDA & OptiX
if(NOT APPLE AND NOT (WIN32 AND CMAKE_SYSTEM_PROCESSOR STREQUAL "ARM64"))
  option(WITH_CYCLES_DEVICE_CUDA "Enable Cycles NVIDIA CUDA compute support" ON)
  option(WITH_CYCLES_DEVICE_OPTIX "Enable Cycles NVIDIA OptiX support" ON)
  mark_as_advanced(WITH_CYCLES_DEVICE_CUDA)

  option(WITH_CYCLES_CUDA_BINARIES "Build Cycles NVIDIA CUDA binaries" OFF)
  set(CYCLES_CUDA_BINARIES_ARCH
    sm_30 sm_35 sm_37 sm_50 sm_52 sm_60 sm_61 sm_70 sm_75 sm_86 sm_89 compute_75
    CACHE STRING "CUDA architectures to build binaries for"
  )
  option(WITH_CYCLES_CUDA_BUILD_SERIAL "\
Build cubins one after another (useful on machines with limited RAM)"
    OFF
  )
  option(WITH_CUDA_DYNLOAD "\
Dynamically load CUDA libraries at runtime (for developers, makes cuda-gdb work)"
    ON
  )

  set(OPTIX_ROOT_DIR "" CACHE PATH "\
Path to the OptiX SDK root directory, for building Cycles OptiX kernels."
  )
  set(CYCLES_RUNTIME_OPTIX_ROOT_DIR "" CACHE PATH "\
Path to the OptiX SDK root directory. \
When set, this path will be used at runtime to compile OptiX kernels."
  )

  mark_as_advanced(CYCLES_CUDA_BINARIES_ARCH)
  mark_as_advanced(WITH_CYCLES_CUDA_BUILD_SERIAL)
  mark_as_advanced(WITH_CUDA_DYNLOAD)
  mark_as_advanced(OPTIX_ROOT_DIR)
  mark_as_advanced(CYCLES_RUNTIME_OPTIX_ROOT_DIR)
endif()

# AMD HIP
if(NOT APPLE AND NOT (WIN32 AND CMAKE_SYSTEM_PROCESSOR STREQUAL "ARM64"))
  option(WITH_CYCLES_DEVICE_HIP "Enable Cycles AMD HIP support" ON)
  option(WITH_CYCLES_HIP_BINARIES "Build Cycles AMD HIP binaries" OFF)
  # Radeon VII (gfx906) not currently working with HIP SDK, so left out of the list.
  set(CYCLES_HIP_BINARIES_ARCH
    gfx900 gfx90c gfx902
    gfx1010 gfx1011 gfx1012
    gfx1030 gfx1031 gfx1032 gfx1034 gfx1035 gfx1036
    gfx1100 gfx1101 gfx1102 gfx1103 gfx1150 gfx1151
    CACHE STRING "AMD HIP architectures to build binaries for"
  )
  mark_as_advanced(WITH_CYCLES_DEVICE_HIP)
  mark_as_advanced(CYCLES_HIP_BINARIES_ARCH)

   option(WITH_CYCLES_DEVICE_HIPRT "Enable Cycles AMD HIPRT support" OFF)
   mark_as_advanced(WITH_CYCLES_DEVICE_HIPRT)

endif()

# Apple Metal
if(APPLE)
  option(WITH_CYCLES_DEVICE_METAL "Enable Cycles Apple Metal compute support" ON)
endif()

# oneAPI
if(NOT APPLE AND NOT (WIN32 AND CMAKE_SYSTEM_PROCESSOR STREQUAL "ARM64"))
  option(WITH_CYCLES_DEVICE_ONEAPI "Enable Cycles oneAPI compute support" OFF)
  option(WITH_CYCLES_ONEAPI_BINARIES "\
Enable Ahead-Of-Time compilation for Cycles oneAPI device"
    OFF
  )
  option(WITH_CYCLES_ONEAPI_HOST_TASK_EXECUTION "\
Switch target of oneAPI implementation from SYCL devices to Host Task (single thread on CPU). \
This option is only for debugging purposes."
    OFF
  )

  # https://www.intel.com/content/www/us/en/develop/documentation/oneapi-dpcpp-cpp-compiler-dev-guide-and-reference/top/compilation/ahead-of-time-compilation.html
  # The target architectures levels can be retrieved from `ocloc` output when running
  # `ocloc compile -device {device_id} test.c` for given GPUs PCI device IDs.
  # 12.55.8 is for Arc Alchemist GPUs. 12.70.4 for Meteor Lake iGPUs.
  set(CYCLES_ONEAPI_INTEL_BINARIES_ARCH 12.55.8 12.70.4 CACHE STRING "\
oneAPI Intel GPU architectures to build binaries for"
  )
  set(CYCLES_ONEAPI_SYCL_TARGETS spir64 spir64_gen CACHE STRING "\
oneAPI targets to build AOT binaries for"
  )

  mark_as_advanced(WITH_CYCLES_ONEAPI_HOST_TASK_EXECUTION)
  mark_as_advanced(CYCLES_ONEAPI_INTEL_BINARIES_ARCH)
  mark_as_advanced(CYCLES_ONEAPI_SYCL_TARGETS)
endif()

# Hydra Render Delegate
option(WITH_CYCLES_HYDRA_RENDER_DELEGATE "Build Cycles Hydra render delegate" ON)

# Error Checking
option(WITH_STRICT_BUILD_OPTIONS "When requirements for a build option are not met, error instead of disabling the option" OFF)

###########################################################################
# Configuration.

include(CheckCXXCompilerFlag)
include(detect_platform)
include(external_libs)
include(configure_build)
include(CTest)

###########################################################################
# Include directories.

include_directories(
	third_party/cuew/include
	third_party/hipew/include
)

###########################################################################
# Sources.

add_subdirectory(src)
add_subdirectory(third_party)
