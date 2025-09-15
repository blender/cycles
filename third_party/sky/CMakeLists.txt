# SPDX-FileCopyrightText: 2002-2022 Blender Authors
#
# SPDX-License-Identifier: BSD-3-Clause

set(INC
  include
)

set(INC_SYS
  ${TBB_INCLUDE_DIRS}
)

set(SRC
  source/sky_single_scattering.cpp
  source/sky_multiple_scattering.cpp
  source/sky_hosek.cpp
  source/sky_hosek_data.h

  include/sky_hosek.h
  include/sky_nishita.h
  source/sky_math.h
)

include_directories(
  ${INC} ${INC_SYS}
)

add_library(extern_sky "${SRC}" "${INC}" "${INC_SYS}")
