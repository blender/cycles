/*
 * Copyright 2011-2014 Blender Foundation
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License
 */

#ifndef __CUEW_H__
#define __CUEW_H__

#ifdef __cplusplus
extern "C" {
#endif

#include <stdlib.h>

/* Defines. */
#define CUEW_VERSION_MAJOR 2
#define CUEW_VERSION_MINOR 0

%DEFINES%

/* Functions which changed 3.1 -> 3.2 for 64 bit stuff,
 * the cuda library has both the old ones for compatibility and new
 * ones with _v2 postfix,
 */
%DEFINES_V2%

/* Types. */
#ifdef _MSC_VER
typedef unsigned __int32 cuuint32_t;
typedef unsigned __int64 cuuint64_t;
#else
#include <stdint.h>
typedef uint32_t cuuint32_t;
typedef uint64_t cuuint64_t;
#endif

#if defined(__x86_64) || defined(AMD64) || defined(_M_AMD64) || defined (__aarch64__)
typedef unsigned long long CUdeviceptr;
#else
typedef unsigned int CUdeviceptr;
#endif


#ifdef _WIN32
#  define CUDAAPI __stdcall
#  define CUDA_CB __stdcall
#else
#  define CUDAAPI
#  define CUDA_CB
#endif

%TYPEDEFS%


/* Function types. */
%FUNC_TYPEDEFS%


/* Function declarations. */
%FUNC_DECLARATIONS%


enum {
  CUEW_SUCCESS = 0,
  CUEW_ERROR_OPEN_FAILED = -1,
  CUEW_ERROR_ATEXIT_FAILED = -2,
};

enum {
	CUEW_INIT_CUDA = 1,
	CUEW_INIT_NVRTC = 2
};

int cuewInit(cuuint32_t flags);
const char *cuewErrorString(CUresult result);
const char *cuewCompilerPath(void);
int cuewCompilerVersion(void);
int cuewNvrtcVersion(void);

#ifdef __cplusplus
}
#endif

#endif  /* __CUEW_H__ */
