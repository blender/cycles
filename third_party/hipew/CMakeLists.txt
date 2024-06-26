set(INC
  .
  include
  src
)

set(INC_SYS

)

set(SRC
  src/hipew.c
  include/hipew.h
)

set(LIB
)

if(HIPRT_INCLUDE_DIR)
  list(APPEND INC_SYS
    ${HIPRT_INCLUDE_DIR}
  )

  list(APPEND SRC
    src/hiprtew.cc
    include/hiprtew.h
  )
endif()

add_library(extern_hipew ${SRC} ${INC} ${INC_SYS})
