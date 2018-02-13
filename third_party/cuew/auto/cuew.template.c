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

#ifdef _MSC_VER
#  if _MSC_VER < 1900
#    define snprintf _snprintf
#  endif
#  define popen _popen
#  define pclose _pclose
#  define _CRT_SECURE_NO_WARNINGS
#endif

#include <cuew.h>
#include <assert.h>
#include <stdio.h>
#include <string.h>
#include <sys/stat.h>

#ifdef _WIN32
#  define WIN32_LEAN_AND_MEAN
#  define VC_EXTRALEAN
#  include <windows.h>

/* Utility macros. */

typedef HMODULE DynamicLibrary;

#  define dynamic_library_open(path)         LoadLibraryA(path)
#  define dynamic_library_close(lib)         FreeLibrary(lib)
#  define dynamic_library_find(lib, symbol)  GetProcAddress(lib, symbol)
#else
#  include <dlfcn.h>

typedef void* DynamicLibrary;

#  define dynamic_library_open(path)         dlopen(path, RTLD_NOW)
#  define dynamic_library_close(lib)         dlclose(lib)
#  define dynamic_library_find(lib, symbol)  dlsym(lib, symbol)
#endif

#define _LIBRARY_FIND_CHECKED(lib, name) \
        name = (t##name *)dynamic_library_find(lib, #name); \
        assert(name);

#define _LIBRARY_FIND(lib, name) \
        name = (t##name *)dynamic_library_find(lib, #name);

#define CUDA_LIBRARY_FIND_CHECKED(name) \
        _LIBRARY_FIND_CHECKED(cuda_lib, name)
#define CUDA_LIBRARY_FIND(name) _LIBRARY_FIND(cuda_lib, name)

#define NVRTC_LIBRARY_FIND_CHECKED(name) \
        _LIBRARY_FIND_CHECKED(nvrtc_lib, name)
#define NVRTC_LIBRARY_FIND(name) _LIBRARY_FIND(nvrtc_lib, name)

static DynamicLibrary cuda_lib;
static DynamicLibrary nvrtc_lib;

/* Function definitions. */
%FUNCTION_DEFINITIONS%


static DynamicLibrary dynamic_library_open_find(const char **paths) {
  int i = 0;
  while (paths[i] != NULL) {
      DynamicLibrary lib = dynamic_library_open(paths[i]);
      if (lib != NULL) {
        return lib;
      }
      ++i;
  }
  return NULL;
}

/* Implementation function. */
static void cuewCudaExit(void) {
  if (cuda_lib != NULL) {
    /*  Ignore errors. */
    dynamic_library_close(cuda_lib);
    cuda_lib = NULL;
  }
}

static int cuewCudaInit(void) {
  /* Library paths. */
#ifdef _WIN32
  /* Expected in c:/windows/system or similar, no path needed. */
  const char *cuda_paths[] = {"nvcuda.dll", NULL};
#elif defined(__APPLE__)
  /* Default installation path. */
  const char *cuda_paths[] = {"/usr/local/cuda/lib/libcuda.dylib", NULL};
#else
  const char *cuda_paths[] = {"libcuda.so", NULL};
#endif
  static int initialized = 0;
  static int result = 0;
  int error, driver_version;

  if (initialized) {
    return result;
  }

  initialized = 1;

  error = atexit(cuewCudaExit);
  if (error) {
    result = CUEW_ERROR_ATEXIT_FAILED;
    return result;
  }

  /* Load library. */
  cuda_lib = dynamic_library_open_find(cuda_paths);

  if (cuda_lib == NULL) {
    result = CUEW_ERROR_OPEN_FAILED;
    return result;
  }

  /* Detect driver version. */
  driver_version = 1000;

  CUDA_LIBRARY_FIND_CHECKED(cuDriverGetVersion);
  if (cuDriverGetVersion) {
    cuDriverGetVersion(&driver_version);
  }

  /* We require version 4.0. */
  if (driver_version < 4000) {
    result = CUEW_ERROR_OPEN_FAILED;
    return result;
  }
  /* Fetch all function pointers. */
%LIB_FIND_CUDA%

  result = CUEW_SUCCESS;
  return result;
}

static void cuewExitNvrtc(void) {
  if (nvrtc_lib != NULL) {
    /*  Ignore errors. */
    dynamic_library_close(nvrtc_lib);
    nvrtc_lib = NULL;
  }
}

static int cuewNvrtcInit(void) {
  /* Library paths. */
#ifdef _WIN32
  /* Expected in c:/windows/system or similar, no path needed. */
  const char *nvrtc_paths[] = {"nvrtc64_80.dll", "nvrtc64_90.dll", "nvrtc64_91.dll", NULL};
#elif defined(__APPLE__)
  /* Default installation path. */
  const char *nvrtc_paths[] = {"/usr/local/cuda/lib/libnvrtc.dylib", NULL};
#else
  const char *nvrtc_paths[] = {"libnvrtc.so",
#  if defined(__x86_64__) || defined(_M_X64)
                               "/usr/local/cuda/lib64/libnvrtc.so",
#else
                               "/usr/local/cuda/lib/libnvrtc.so",
#endif
                               NULL};
#endif
  static int initialized = 0;
  static int result = 0;
  int error;

  if (initialized) {
    return result;
  }

  initialized = 1;

  error = atexit(cuewExitNvrtc);
  if (error) {
    result = CUEW_ERROR_ATEXIT_FAILED;
    return result;
  }

  /* Load library. */
  nvrtc_lib = dynamic_library_open_find(nvrtc_paths);

  if (nvrtc_lib == NULL) {
    result = CUEW_ERROR_OPEN_FAILED;
    return result;
  }

%LIB_FIND_NVRTC%

  result = CUEW_SUCCESS;
  return result;
}


int cuewInit(cuuint32_t flags) {
	int result = CUEW_SUCCESS;

	if (flags & CUEW_INIT_CUDA) {
		result = cuewCudaInit();
		if (result != CUEW_SUCCESS) {
			return result;
		}
	}

	if (flags & CUEW_INIT_NVRTC) {
		result = cuewNvrtcInit();
		if (result != CUEW_SUCCESS) {
			return result;
		}
	}

	return result;
}


const char *cuewErrorString(CUresult result) {
  switch (result) {
    case CUDA_SUCCESS: return "No errors";
%CUDA_ERRORS%
    default: return "Unknown CUDA error value";
  }
}

static void path_join(const char *path1,
                      const char *path2,
                      int maxlen,
                      char *result) {
#if defined(WIN32) || defined(_WIN32)
  const char separator = '\\';
#else
  const char separator = '/';
#endif
  int n = snprintf(result, maxlen, "%s%c%s", path1, separator, path2);
  if (n != -1 && n < maxlen) {
    result[n] = '\0';
  }
  else {
    result[maxlen - 1] = '\0';
  }
}

static int path_exists(const char *path) {
  struct stat st;
  if (stat(path, &st)) {
    return 0;
  }
  return 1;
}

const char *cuewCompilerPath(void) {
#ifdef _WIN32
  const char *defaultpaths[] = {"C:/CUDA/bin", NULL};
  const char *executable = "nvcc.exe";
#else
  const char *defaultpaths[] = {
    "/Developer/NVIDIA/CUDA-5.0/bin",
    "/usr/local/cuda-5.0/bin",
    "/usr/local/cuda/bin",
    "/Developer/NVIDIA/CUDA-6.0/bin",
    "/usr/local/cuda-6.0/bin",
    "/Developer/NVIDIA/CUDA-5.5/bin",
    "/usr/local/cuda-5.5/bin",
    NULL};
  const char *executable = "nvcc";
#endif
  int i;

  const char *binpath = getenv("CUDA_BIN_PATH");

  static char nvcc[65536];

  if (binpath) {
    path_join(binpath, executable, sizeof(nvcc), nvcc);
    if (path_exists(nvcc)) {
      return nvcc;
    }
  }

  for (i = 0; defaultpaths[i]; ++i) {
    path_join(defaultpaths[i], executable, sizeof(nvcc), nvcc);
    if (path_exists(nvcc)) {
      return nvcc;
    }
  }

#ifndef _WIN32
  {
    FILE *handle = popen("which nvcc", "r");
    if (handle) {
      char buffer[4096] = {0};
      int len = fread(buffer, 1, sizeof(buffer) - 1, handle);
      buffer[len] = '\0';
      pclose(handle);
      if (buffer[0]) {
        return "nvcc";
      }
    }
  }
#endif

  return NULL;
}

int cuewNvrtcVersion(void) {
  int major, minor;
  if (nvrtcVersion) {
    nvrtcVersion(&major, &minor);
    return 10 * major + minor;
  }
  return 0;
}

int cuewCompilerVersion(void) {
  const char *path = cuewCompilerPath();
  const char *marker = "Cuda compilation tools, release ";
  FILE *pipe;
  int major, minor;
  char *versionstr;
  char buf[128];
  char output[65536] = "\0";
  char command[65536] = "\0";

  if (path == NULL) {
    return 0;
  }

  /* get --version output */
  strncpy(command, path, sizeof(command));
  strncat(command, " --version", sizeof(command) - strlen(path));
  pipe = popen(command, "r");
  if (!pipe) {
    fprintf(stderr, "CUDA: failed to run compiler to retrieve version");
    return 0;
  }

  while (!feof(pipe)) {
    if (fgets(buf, sizeof(buf), pipe) != NULL) {
      strncat(output, buf, sizeof(output) - strlen(output) - 1);
    }
  }

  pclose(pipe);

  /* parse version number */
  versionstr = strstr(output, marker);
  if (versionstr == NULL) {
    fprintf(stderr, "CUDA: failed to find version number in:\n\n%s\n", output);
    return 0;
  }
  versionstr += strlen(marker);

  if (sscanf(versionstr, "%d.%d", &major, &minor) < 2) {
    fprintf(stderr, "CUDA: failed to parse version number from:\n\n%s\n", output);
    return 0;
  }

  return 10 * major + minor;
}

