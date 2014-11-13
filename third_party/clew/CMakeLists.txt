set(SRC
	src/clew.c
)

set(SRC_HEADERS
	include/clew.h
)

add_definitions(-DCL_USE_DEPRECATED_OPENCL_1_1_APIS)
include_directories(
	.
	include
)

add_library(extern_clew ${SRC} ${SRC_HEADERS})
