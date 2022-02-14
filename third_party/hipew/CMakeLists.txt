set(SRC
	src/hipew.c
)

set(SRC_HEADERS
	include/hipew.h
)

include_directories(
	.
	include
)

add_library(extern_hipew ${SRC} ${SRC_HEADERS})
