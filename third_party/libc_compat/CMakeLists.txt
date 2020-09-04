# Copyright 2020 Blender Foundation
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

set(INC
  .
)

set(INC_SYS
)

set(SRC
  libc_compat.c
)

set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -ffast-math")

include_directories(
  ${INC} ${INC_SYS}
)

add_library(extern_libc_compat "${SRC}" "${INC}" "${INC_SYS}")
