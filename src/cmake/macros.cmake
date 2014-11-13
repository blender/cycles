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
