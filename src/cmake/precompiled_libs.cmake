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
	if(CMAKE_CL_64)
		if(MSVC12)
			set(_lib_DIR "${CMAKE_SOURCE_DIR}/../lib/win64_vc12")
		elseif(MSVC14)
			set(_lib_DIR "${CMAKE_SOURCE_DIR}/../lib/win64_vc14")
		else()
			message(FATAL_ERROR "Unsupported Visual Studio Version")
		endif()
	else()
		if(MSVC12)
			set(_lib_DIR "${CMAKE_SOURCE_DIR}/../lib/windows_vc12")
		elseif(MSVC14)
			set(_lib_DIR "${CMAKE_SOURCE_DIR}/../lib/windows_vc14")
		else()
			message(FATAL_ERROR "Unsupported Visual Studio Version")
		endif()
	endif()
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
if (MSVC)
	set(JPEG_LIBRARIES ${JPEG_LIBRARIES};${_lib_DIR}/openjpeg/lib/openjpeg.lib)
endif()
# TODO(sergey): Move naming to a consistent state.
set(TIFF_LIBRARY "${_lib_DIR}/tiff/lib/libtiff${CMAKE_STATIC_LIBRARY_SUFFIX}")

if(APPLE)
	# Precompiled PNG library depends on ZLib.
	find_package(ZLIB REQUIRED)
	list(APPEND PLATFORM_LINKLIBS ${ZLIB_LIBRARIES})

	# Glew
	_set_default(GLEW_ROOT_DIR "${_lib_DIR}/glew")
elseif(MSVC)
	set(ZLIB_INCLUDE_DIRS ${_lib_DIR}/zlib/include)
	set(ZLIB_LIBRARIES ${_lib_DIR}/zlib/lib/libz_st.lib)
	set(ZLIB_INCLUDE_DIR ${_lib_DIR}/zlib/include)
	set(ZLIB_LIBRARY ${_lib_DIR}/zlib/lib/libz_st.lib)
	set(ZLIB_DIR ${_lib_DIR}/zlib)
	find_package(ZLIB REQUIRED)
	list(APPEND PLATFORM_LINKLIBS ${ZLIB_LIBRARIES})

	# TODO(sergey): On Windows llvm-config doesn't give proper results for the
	# library names, use hardcoded libraries for now.
	file(GLOB LLVM_LIBRARIES_RELEASE ${LLVM_ROOT_DIR}/lib/*.lib)
	file(GLOB LLVM_LIBRARIES_DEBUG ${LLVM_ROOT_DIR}/debug/lib/*.lib)
	set(LLVM_LIBRARIES)
	foreach(_llvm_library ${LLVM_LIBRARIES_RELEASE})
		set(LLVM_LIBRARIES ${LLVM_LIBRARIES} optimized ${_llvm_library})
	endforeach()
	foreach(_llvm_library ${LLVM_LIBRARIES_DEBUG})
		set(LLVM_LIBRARIES ${LLVM_LIBRARIES} debug ${_llvm_library})
	endforeach()

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

	# Special exceptions for libraries which needs explicit debug version
	set(OPENIMAGEIO_LIBRARY
		optimized ${OPENIMAGEIO_ROOT_DIR}/lib/OpenImageIO.lib
		optimized ${OPENIMAGEIO_ROOT_DIR}/lib/OpenImageIO_Util.lib
		debug ${OPENIMAGEIO_ROOT_DIR}/lib/OpenImageIO_d.lib
		debug ${OPENIMAGEIO_ROOT_DIR}/lib/OpenImageIO_Util_d.lib
	)

	set(OSL_OSLCOMP_LIBRARY
		optimized ${OSL_ROOT_DIR}/lib/oslcomp.lib
		debug ${OSL_ROOT_DIR}/lib/oslcomp_d.lib
	)
	set(OSL_OSLEXEC_LIBRARY
		optimized ${OSL_ROOT_DIR}/lib/oslexec.lib
		debug ${OSL_ROOT_DIR}/lib/oslexec_d.lib
	)
	set(OSL_OSLQUERY_LIBRARY
		optimized ${OSL_ROOT_DIR}/lib/oslquery.lib
		debug ${OSL_ROOT_DIR}/lib/oslquery_d.lib
	)

	set(OPENEXR_IEX_LIBRARY
		optimized ${OPENEXR_ROOT_DIR}/lib/Iex-2_2.lib
		debug ${OPENEXR_ROOT_DIR}/lib/Iex-2_2_d.lib
	)
	set(OPENEXR_HALF_LIBRARY
		optimized ${OPENEXR_ROOT_DIR}/lib/Half.lib
		debug ${OPENEXR_ROOT_DIR}/lib/Half_d.lib
	)
	set(OPENEXR_ILMIMF_LIBRARY
		optimized ${OPENEXR_ROOT_DIR}/lib/IlmImf-2_2.lib
		debug ${OPENEXR_ROOT_DIR}/lib/IlmImf-2_2_d.lib
	)
	set(OPENEXR_IMATH_LIBRARY
		optimized ${OPENEXR_ROOT_DIR}/lib/Imath-2_2.lib
		debug ${OPENEXR_ROOT_DIR}/lib/Imath-2_2_d.lib
	)
	set(OPENEXR_ILMTHREAD_LIBRARY
		optimized ${OPENEXR_ROOT_DIR}/lib/IlmThread-2_2.lib
		debug ${OPENEXR_ROOT_DIR}/lib/IlmThread-2_2_d.lib
	)
endif()

unset(_lib_DIR)
