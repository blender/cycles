set(SRC
	src/cuew.c
)

set(SRC_HEADERS
	include/cuew.h
)

include_directories(
	.
	include
)

add_library(extern_cuew ${SRC} ${SRC_HEADERS})
