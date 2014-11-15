macro(_set_default variable value)
	if(NOT ${variable})
		set(${variable} ${value})
	endif()
endmacro()

# Hardcoded libraries for platforms where we've got precompiled libraries.
if(APPLE)
	# Path to the folder with precompiled libarries.
	set(_lib_DIR "${CMAKE_SOURCE_DIR}/../lib/darwin-9.x.universal")

	# Tips for where to find some packages.
	# Don't overwrite if passed via command line arguments.
	_set_default(OPENIMAGEIO_ROOT_DIR "${_lib_DIR}/openimageio")
	_set_default(BOOST_ROOT "${_lib_DIR}/boost")
	_set_default(LLVM_ROOT_DIR "${_lib_DIR}/llvm")
	_set_default(OSL_ROOT_DIR "${_lib_DIR}/osl")
	_set_default(OPENEXR_ROOT_DIR "${_lib_DIR}/openexr")

	# Some dependnecies are still hardcoded..
	set(PNG_LIBPATH "${_lib_DIR}/png/lib")
	set(JPEG_LIBPATH "${_lib_DIR}/jpeg/lib")
	set(TIFF_LIBPATH "${_lib_DIR}/tiff/lib")

	list(APPEND PLATFORM_LINKLIBS -lpng -ljpeg -ltiff -lz)
elseif(WIN32)
	message(FATAL_ERROR "Windows platform is not hooked up to CMake yet")
endif()

unset(_lib_DIR)
