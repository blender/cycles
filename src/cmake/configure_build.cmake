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

###########################################################################
# Global generic CMake settings.

set(CMAKE_ARCHIVE_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/lib)
set(CMAKE_LIBRARY_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/lib)
set(CMAKE_RUNTIME_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/bin)

###########################################################################
# Per-compiler configuration.

if(CMAKE_COMPILER_IS_GNUCXX)
	set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -Wall -Wno-sign-compare -fno-strict-aliasing")
	set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -Wall -Wno-sign-compare -fno-strict-aliasing -std=c++17")
elseif(CMAKE_C_COMPILER_ID MATCHES "Clang")
	set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -Wall -Wno-sign-compare -fno-strict-aliasing")
	set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -Wall -Wno-sign-compare -fno-strict-aliasing -std=c++17")
endif()

if(APPLE)
	if(NOT ${CMAKE_GENERATOR} MATCHES "Xcode")
		# force CMAKE_OSX_DEPLOYMENT_TARGET for makefiles, will not work else ( cmake bug ? )
		set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -mmacosx-version-min=${CMAKE_OSX_DEPLOYMENT_TARGET}")
		set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -mmacosx-version-min=${CMAKE_OSX_DEPLOYMENT_TARGET} -std=c++17 -stdlib=libc++")
		add_definitions("-DMACOSX_DEPLOYMENT_TARGET=${CMAKE_OSX_DEPLOYMENT_TARGET}")
	endif()
elseif(MSVC)
	set(CMAKE_CXX_FLAGS "/nologo /J /Gd /EHsc /bigobj /MP /std:c++17" CACHE STRING "MSVC MD C++ flags " FORCE)
	set(CMAKE_C_FLAGS "/nologo /J /Gd /MP /bigobj" CACHE STRING "MSVC MD C++ flags " FORCE)

	if(CMAKE_CL_64)
		set(CMAKE_CXX_FLAGS_DEBUG "/Od /RTC1 /MDd /Zi" CACHE STRING "MSVC MD flags " FORCE)
	else()
		set(CMAKE_CXX_FLAGS_DEBUG "/Od /RTC1 /MDd /ZI" CACHE STRING "MSVC MD flags " FORCE)
	endif()
	set(CMAKE_CXX_FLAGS_RELEASE "/O2 /Ob2 /MD" CACHE STRING "MSVC MD flags " FORCE)
	set(CMAKE_CXX_FLAGS_MINSIZEREL "/O1 /Ob1 /MD" CACHE STRING "MSVC MD flags " FORCE)
	set(CMAKE_CXX_FLAGS_RELWITHDEBINFO "/O2 /Ob1 /MD /Zi" CACHE STRING "MSVC MD flags " FORCE)
	if(CMAKE_CL_64)
		set(CMAKE_C_FLAGS_DEBUG "/Od /RTC1 /MDd /Zi" CACHE STRING "MSVC MD flags " FORCE)
	else()
		set(CMAKE_C_FLAGS_DEBUG "/Od /RTC1 /MDd /ZI" CACHE STRING "MSVC MD flags " FORCE)
	endif()
	set(CMAKE_C_FLAGS_RELEASE "/O2 /Ob2 /MD" CACHE STRING "MSVC MD flags " FORCE)
	set(CMAKE_C_FLAGS_MINSIZEREL "/O1 /Ob1 /MD" CACHE STRING "MSVC MD flags " FORCE)
	set(CMAKE_C_FLAGS_RELWITHDEBINFO "/O2 /Ob1 /MD /Zi" CACHE STRING "MSVC MD flags " FORCE)

	list(APPEND PLATFORM_LINKLIBS psapi)
endif()

if(UNIX AND NOT APPLE)
  if(NOT WITH_CXX11_ABI)
    set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -D_GLIBCXX_USE_CXX11_ABI=0")
    set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -D_GLIBCXX_USE_CXX11_ABI=0")
  endif()
endif()
