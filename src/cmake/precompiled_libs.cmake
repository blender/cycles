###########################################################################
# Helper macros
macro(_set_default variable value)
	if(NOT ${variable})
		set(${variable} ${value})
	endif()
endmacro()

###########################################################################
# Hardcoded libraries for platforms where we've got precompiled libraries.

###########################################################################
# Path to the folder with precompiled libarries.
# We demand libraries folders to be called exactly the same for all platforms.
if(APPLE)
	set(_lib_DIR "${CMAKE_SOURCE_DIR}/../lib/darwin-9.x.universal")
elseif(WIN32)
	if(NOT MSVC12 OR NOT CMAKE_CL_64)
		# TODO(sergey): Would be cool to support GCC/CLang as well.
		message(FATAL_ERROR "Currently only MSVC 2012 64bit is supported")
	endif()
	set(_lib_DIR "${CMAKE_SOURCE_DIR}/../lib/win64_vc12")
endif()

###########################################################################
# Tips for where to find some packages.
# Don't overwrite if passed via command line arguments.

_set_default(OPENIMAGEIO_ROOT_DIR "${_lib_DIR}/openimageio")
_set_default(BOOST_ROOT "${_lib_DIR}/boost")
_set_default(LLVM_ROOT_DIR "${_lib_DIR}/llvm")
_set_default(OSL_ROOT_DIR "${_lib_DIR}/osl")
_set_default(OPENEXR_ROOT_DIR "${_lib_DIR}/openexr")

# Dependencies for OpenImageIO.
set(PNG_LIBRARIES "${_lib_DIR}/png/lib/libpng${CMAKE_STATIC_LIBRARY_SUFFIX}")
set(JPEG_LIBRARIES "${_lib_DIR}/jpeg/lib/libjpeg${CMAKE_STATIC_LIBRARY_SUFFIX}")
# TODO(sergey): Move naming to a consistent state.
set(TIFF_LIBRARY "${_lib_DIR}/tiff/lib/libtiff${CMAKE_STATIC_LIBRARY_SUFFIX}")

if(APPLE)
	# Precompiled PNG library depends on ZLib.
	find_package(ZLIB REQUIRED)
	list(APPEND PLATFORM_LINKLIBS ${ZLIB_LIBRARIES})
elseif(MSVC)
	# TODO(sergey): On Windows llvm-config doesn't give proper results for the
	# library names, use hardcoded libraries for now.
	file(GLOB LLVM_LIBRARIES ${LLVM_ROOT_DIR}/lib/*.lib)

	# On Windows we use precompiled GLEW and GLUT.
	_set_default(GLEW_ROOT_DIR "${_lib_DIR}/opengl")
	_set_default(CYCLES_GLUT "${_lib_DIR}/opengl")
	set(GLUT_glut_LIBRARY "${_lib_DIR}/opengl/lib/freeglut_static.lib")

	set(Boost_USE_STATIC_RUNTIME ON)
	set(Boost_USE_MULTITHREADED ON)
	set(Boost_USE_STATIC_LIBS ON)

	# Special tricks for precompiled PThreads.
	set(PTHREADS_LIBRARIES "${_lib_DIR}/pthreads/lib/pthreadVC2.lib")
	include_directories("${_lib_DIR}/pthreads/include")

	# We need to tell compiler we're gonna to use static versions
	# of OpenImageIO and GL*, otherwise linker will try to use
	# dynamic one which we don't have and don't want even.
	add_definitions(
		-DOIIO_STATIC_BUILD
		-DGLEW_STATIC
		-DFREEGLUT_STATIC
		-DFREEGLUT_LIB_PRAGMAS=0
	)
endif()

unset(_lib_DIR)
