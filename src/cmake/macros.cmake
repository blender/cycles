macro(ADD_CHECK_CXX_COMPILER_FLAG
	_CXXFLAGS
	_CACHE_VAR
	_FLAG)

	include(CheckCXXCompilerFlag)

	CHECK_CXX_COMPILER_FLAG("${_FLAG}" "${_CACHE_VAR}")
	if(${_CACHE_VAR})
		# message(STATUS "Using CXXFLAG: ${_FLAG}")
		set(${_CXXFLAGS} "${${_CXXFLAGS}} ${_FLAG}")
	else()
		message(STATUS "Unsupported CXXFLAG: ${_FLAG}")
	endif()
endmacro()

# pair of macros to allow libraries to be specify files to install, but to
# only install them at the end so the directories don't get cleared with
# the files in them. used by cycles to install addon.
macro(delayed_install
	base
	files
	destination)

	foreach(f ${files})
		if(IS_ABSOLUTE ${f})
			set_property(GLOBAL APPEND PROPERTY DELAYED_INSTALL_FILES ${f})
		else()
			set_property(GLOBAL APPEND PROPERTY DELAYED_INSTALL_FILES ${base}/${f})
		endif()
		set_property(GLOBAL APPEND PROPERTY DELAYED_INSTALL_DESTINATIONS ${destination})
	endforeach()
endmacro()

# note this is a function instead of a macro so that ${BUILD_TYPE} in targetdir
# does not get expanded in calling but is preserved
function(delayed_do_install
	targetdir)

	get_property(files GLOBAL PROPERTY DELAYED_INSTALL_FILES)
	get_property(destinations GLOBAL PROPERTY DELAYED_INSTALL_DESTINATIONS)

	if(files)
		list(LENGTH files n)
		math(EXPR n "${n}-1")

		foreach(i RANGE ${n})
			list(GET files ${i} f)
			list(GET destinations ${i} d)
			install(FILES ${f} DESTINATION ${targetdir}/${d})
		endforeach()
	endif()
endfunction()

macro(target_link_libraries_optimized TARGET LIBS)
	foreach(_LIB ${LIBS})
		target_link_libraries(${TARGET} optimized "${_LIB}")
	endforeach()
	unset(_LIB)
endmacro()

macro(target_link_libraries_debug TARGET LIBS)
	foreach(_LIB ${LIBS})
		target_link_libraries(${TARGET} debug "${_LIB}")
	endforeach()
	unset(_LIB)
endmacro()

# foo_bar.spam --> foo_barMySuffix.spam
macro(file_suffix
	file_name_new file_name file_suffix
	)

	get_filename_component(_file_name_PATH ${file_name} PATH)
	get_filename_component(_file_name_NAME_WE ${file_name} NAME_WE)
	get_filename_component(_file_name_EXT ${file_name} EXT)
	set(${file_name_new} "${_file_name_PATH}/${_file_name_NAME_WE}${file_suffix}${_file_name_EXT}")

	unset(_file_name_PATH)
	unset(_file_name_NAME_WE)
	unset(_file_name_EXT)
endmacro()

# useful for adding debug suffix to library lists:
# /somepath/foo.lib --> /somepath/foo_d.lib
macro(file_list_suffix
	fp_list_new fp_list fn_suffix
	)

	# incase of empty list
	set(_fp)
	set(_fp_suffixed)

	set(fp_list_new)

	foreach(_fp ${fp_list})
		file_suffix(_fp_suffixed "${_fp}" "${fn_suffix}")
		list(APPEND "${fp_list_new}" "${_fp_suffixed}")
	endforeach()

	unset(_fp)
	unset(_fp_suffixed)

endmacro()

macro(target_link_libraries_decoupled target libraries_var)
	if(NOT MSVC)
		target_link_libraries(${target} ${${libraries_var}})
	else()
		# For MSVC we link to different libraries depending whether
		# release or debug target is being built.
		file_list_suffix(_libraries_debug "${${libraries_var}}" "_d")
		target_link_libraries_debug(${target} "${_libraries_debug}")
		target_link_libraries_optimized(${target} "${${libraries_var}}")
		unset(_libraries_debug)
	endif()
endmacro()

macro(remove_cc_flag
        flag)

	string(REGEX REPLACE ${flag} "" CMAKE_C_FLAGS "${CMAKE_C_FLAGS}")
	string(REGEX REPLACE ${flag} "" CMAKE_C_FLAGS_DEBUG "${CMAKE_C_FLAGS_DEBUG}")
	string(REGEX REPLACE ${flag} "" CMAKE_C_FLAGS_RELEASE "${CMAKE_C_FLAGS_RELEASE}")
	string(REGEX REPLACE ${flag} "" CMAKE_C_FLAGS_MINSIZEREL "${CMAKE_C_FLAGS_MINSIZEREL}")
	string(REGEX REPLACE ${flag} "" CMAKE_C_FLAGS_RELWITHDEBINFO "${CMAKE_C_FLAGS_RELWITHDEBINFO}")

	string(REGEX REPLACE ${flag} "" CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS}")
	string(REGEX REPLACE ${flag} "" CMAKE_CXX_FLAGS_DEBUG "${CMAKE_CXX_FLAGS_DEBUG}")
	string(REGEX REPLACE ${flag} "" CMAKE_CXX_FLAGS_RELEASE "${CMAKE_CXX_FLAGS_RELEASE}")
	string(REGEX REPLACE ${flag} "" CMAKE_CXX_FLAGS_MINSIZEREL "${CMAKE_CXX_FLAGS_MINSIZEREL}")
	string(REGEX REPLACE ${flag} "" CMAKE_CXX_FLAGS_RELWITHDEBINFO "${CMAKE_CXX_FLAGS_RELWITHDEBINFO}")

endmacro()

macro(remove_extra_strict_flags)
	if(CMAKE_COMPILER_IS_GNUCC)
		remove_cc_flag("-Wunused-parameter")
	endif()

	if(CMAKE_C_COMPILER_ID MATCHES "Clang")
		remove_cc_flag("-Wunused-parameter")
	endif()

	if(MSVC)
		# TODO
	endif()
endmacro()

macro(TEST_UNORDERED_MAP_SUPPORT)
	# - Detect unordered_map availability
	# Test if a valid implementation of unordered_map exists
	# and define the include path
	# This module defines
	#  HAVE_UNORDERED_MAP, whether unordered_map implementation was found
	#  
	#  HAVE_STD_UNORDERED_MAP_HEADER, <unordered_map.h> was found
	#  HAVE_UNORDERED_MAP_IN_STD_NAMESPACE, unordered_map is in namespace std
	#  HAVE_UNORDERED_MAP_IN_TR1_NAMESPACE, unordered_map is in namespace std::tr1
	#  
	#  UNORDERED_MAP_INCLUDE_PREFIX, include path prefix for unordered_map, if found
	#  UNORDERED_MAP_NAMESPACE, namespace for unordered_map, if found

	include(CheckIncludeFileCXX)
	CHECK_INCLUDE_FILE_CXX("unordered_map" HAVE_STD_UNORDERED_MAP_HEADER)
	if(HAVE_STD_UNORDERED_MAP_HEADER)
		# Even so we've found unordered_map header file it doesn't
		# mean unordered_map and unordered_set will be declared in
		# std namespace.
		#
		# Namely, MSVC 2008 have unordered_map header which declares
		# unordered_map class in std::tr1 namespace. In order to support
		# this, we do extra check to see which exactly namespace is
		# to be used.

		include(CheckCXXSourceCompiles)
		CHECK_CXX_SOURCE_COMPILES("#include <unordered_map>
		                          int main() {
		                            std::unordered_map<int, int> map;
		                            return 0;
		                          }"
		                          HAVE_UNORDERED_MAP_IN_STD_NAMESPACE)
		if(HAVE_UNORDERED_MAP_IN_STD_NAMESPACE)
			message(STATUS "Found unordered_map/set in std namespace.")

			set(HAVE_UNORDERED_MAP "TRUE")
			set(UNORDERED_MAP_INCLUDE_PREFIX "")
			set(UNORDERED_MAP_NAMESPACE "std")
		else()
			CHECK_CXX_SOURCE_COMPILES("#include <unordered_map>
			                          int main() {
			                            std::tr1::unordered_map<int, int> map;
			                            return 0;
			                          }"
			                          HAVE_UNORDERED_MAP_IN_TR1_NAMESPACE)
			if(HAVE_UNORDERED_MAP_IN_TR1_NAMESPACE)
				message(STATUS "Found unordered_map/set in std::tr1 namespace.")

				set(HAVE_UNORDERED_MAP "TRUE")
				set(UNORDERED_MAP_INCLUDE_PREFIX "")
				set(UNORDERED_MAP_NAMESPACE "std::tr1")
			else()
				message(STATUS "Found <unordered_map> but cannot find either std::unordered_map "
				        "or std::tr1::unordered_map.")
			endif()
		endif()
	else()
		CHECK_INCLUDE_FILE_CXX("tr1/unordered_map" HAVE_UNORDERED_MAP_IN_TR1_NAMESPACE)
		if(HAVE_UNORDERED_MAP_IN_TR1_NAMESPACE)
			message(STATUS "Found unordered_map/set in std::tr1 namespace.")

			set(HAVE_UNORDERED_MAP "TRUE")
			set(UNORDERED_MAP_INCLUDE_PREFIX "tr1")
			set(UNORDERED_MAP_NAMESPACE "std::tr1")
		else()
			message(STATUS "Unable to find <unordered_map> or <tr1/unordered_map>. ")
		endif()
	endif()
endmacro()

macro(TEST_SHARED_PTR_SUPPORT)
	# This check are coming from Ceres library.
	#
	# Find shared pointer header and namespace.
	#
	# This module defines the following variables:
	#
	# SHARED_PTR_FOUND: TRUE if shared_ptr found.
	# SHARED_PTR_TR1_MEMORY_HEADER: True if <tr1/memory> header is to be used
	# for the shared_ptr object, otherwise use <memory>.
	# SHARED_PTR_TR1_NAMESPACE: TRUE if shared_ptr is defined in std::tr1 namespace,
	# otherwise it's assumed to be defined in std namespace.

	include(CheckIncludeFileCXX)
	set(SHARED_PTR_FOUND FALSE)
	CHECK_INCLUDE_FILE_CXX(memory HAVE_STD_MEMORY_HEADER)
	if(HAVE_STD_MEMORY_HEADER)
		# Finding the memory header doesn't mean that shared_ptr is in std
		# namespace.
		#
		# In particular, MSVC 2008 has shared_ptr declared in std::tr1.  In
		# order to support this, we do an extra check to see which namespace
		# should be used.
		include(CheckCXXSourceCompiles)
		CHECK_CXX_SOURCE_COMPILES("#include <memory>
		                           int main() {
		                             std::shared_ptr<int> int_ptr;
		                             return 0;
		                           }"
		                          HAVE_SHARED_PTR_IN_STD_NAMESPACE)

		if(HAVE_SHARED_PTR_IN_STD_NAMESPACE)
			message("-- Found shared_ptr in std namespace using <memory> header.")
			set(SHARED_PTR_FOUND TRUE)
		else()
			CHECK_CXX_SOURCE_COMPILES("#include <memory>
			                           int main() {
			                           std::tr1::shared_ptr<int> int_ptr;
			                           return 0;
			                           }"
			                          HAVE_SHARED_PTR_IN_TR1_NAMESPACE)
			if(HAVE_SHARED_PTR_IN_TR1_NAMESPACE)
				message("-- Found shared_ptr in std::tr1 namespace using <memory> header.")
				set(SHARED_PTR_TR1_NAMESPACE TRUE)
				set(SHARED_PTR_FOUND TRUE)
			endif()
		endif()
	endif()

	if(NOT SHARED_PTR_FOUND)
		# Further, gcc defines shared_ptr in std::tr1 namespace and
		# <tr1/memory> is to be included for this. And what makes things
		# even more tricky is that gcc does have <memory> header, so
		# all the checks above wouldn't find shared_ptr.
		CHECK_INCLUDE_FILE_CXX("tr1/memory" HAVE_TR1_MEMORY_HEADER)
		if(HAVE_TR1_MEMORY_HEADER)
			CHECK_CXX_SOURCE_COMPILES("#include <tr1/memory>
			                           int main() {
			                           std::tr1::shared_ptr<int> int_ptr;
			                           return 0;
			                           }"
			                           HAVE_SHARED_PTR_IN_TR1_NAMESPACE_FROM_TR1_MEMORY_HEADER)
			if(HAVE_SHARED_PTR_IN_TR1_NAMESPACE_FROM_TR1_MEMORY_HEADER)
				message("-- Found shared_ptr in std::tr1 namespace using <tr1/memory> header.")
				set(SHARED_PTR_TR1_MEMORY_HEADER TRUE)
				set(SHARED_PTR_TR1_NAMESPACE TRUE)
				set(SHARED_PTR_FOUND TRUE)
			endif()
		endif()
	endif()
endmacro()
