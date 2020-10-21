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

cmake_minimum_required(VERSION 2.8)

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

# Avoid having empty buildtype.
set(CMAKE_BUILD_TYPE_INIT "Release")


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

option(WITH_CPU_SSE                 "Enable SIMD instruction if they're detected on the host machine" ON)
option(WITH_CYCLES_STANDALONE_GUI   "Build Cycles standalone with GUI" ON)
option(WITH_CYCLES_OSL              "Build Cycles with OSL support" ON)
option(WITH_CYCLES_OPENCOLORIO      "Build Cycles with OpenColorIO support" ON)
option(WITH_CYCLES_OPENSUBDIV       "Build Cycles with OpenSubdiv support" ON)
option(WITH_CYCLES_OPENIMAGEDENOISE "Build Cycles with OpenImageDenoise support" ON)
option(WITH_CYCLES_OPENVDB          "Build Cycles with OpenVDB support" ON)
option(WITH_CYCLES_EMBREE           "Build Cycles with embree support" ON)
option(WITH_CYCLES_LOGGING          "Build Cycles with logging support" OFF)
option(WITH_CYCLES_DEBUG            "Build Cycles with with extra debug capabilties" OFF)
option(WITH_CYCLES_CUDA_BINARIES    "Build Cycles CUDA binaries" OFF)
set(CYCLES_CUDA_BINARIES_ARCH sm_20 sm_21 sm_30 sm_35 sm_50 sm_52 CACHE STRING "CUDA architectures to build binaries for")
mark_as_advanced(CYCLES_CUDA_BINARIES_ARCH)
if(UNIX AND NOT APPLE)
  option(WITH_CXX11_ABI              "Build with glibc C++11 ABI. Precompiled libraries are built with the older ABI" ON)
endif()

option(WITH_CUDA_DYNLOAD           "Dynamically load CUDA libraries at runtime" ON)
mark_as_advanced(WITH_CUDA_DYNLOAD)

include(external_libs)

###########################################################################
# Configuration.

include(CheckCXXCompilerFlag)
include(configure_build)

###########################################################################
# Include directories.

include_directories(
	third_party/cuew/include
	third_party/clew/include
)

###########################################################################
# Sources.

add_subdirectory(src)
add_subdirectory(third_party)
