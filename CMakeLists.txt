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

if(NOT (${CMAKE_VERSION} VERSION_LESS 3.0))
	# Keep until CMake-3.0 is min requirement.
	cmake_policy(SET CMP0043 OLD)
endif()

###########################################################################
# Macros and utilities.

list(APPEND CMAKE_MODULE_PATH
	"${CMAKE_SOURCE_DIR}/src/cmake"
	"${CMAKE_SOURCE_DIR}/src/cmake/Modules"
)
include("${CMAKE_SOURCE_DIR}/src/cmake/macros.cmake")

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
set_property(DIRECTORY APPEND PROPERTY COMPILE_DEFINITIONS_DEBUG           DEBUG _DEBUG)
set_property(DIRECTORY APPEND PROPERTY COMPILE_DEFINITIONS_RELEASE         NDEBUG)
set_property(DIRECTORY APPEND PROPERTY COMPILE_DEFINITIONS_MINSIZEREL      NDEBUG)
set_property(DIRECTORY APPEND PROPERTY COMPILE_DEFINITIONS_RELWITHDEBINFO  NDEBUG)

###########################################################################
# Initialize project.

project(Cycles)

###########################################################################
# Options.

option(WITH_CPU_SSE                "Enable SIMD instruction if they're detected on the host machine" ON)
option(WITH_CYCLES_STANDALONE_GUI  "Build Cycles standalone with GUI" ON)
option(WITH_CYCLES_OSL             "Build Cycles with OSL support" OFF)
option(WITH_CYCLES_LOGGING         "Build Cycles with logging support" OFF)
option(WITH_CYCLES_DEBUG           "Build Cycles with with extra debug capabilties" OFF)
option(WITH_CYCLES_CUDA_BINARIES   "Build Cycles CUDA binaries" OFF)
set(CYCLES_CUDA_BINARIES_ARCH sm_20 sm_21 sm_30 sm_35 sm_50 sm_52 CACHE STRING "CUDA architectures to build binaries for")
mark_as_advanced(CYCLES_CUDA_BINARIES_ARCH)

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
