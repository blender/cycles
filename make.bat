@echo off

REM Convenience wrapper for CMake commands

setlocal enableextensions enabledelayedexpansion

set BUILD_DIR=build
set PYTHON=python
set COMMAND=%1

if "%COMMAND%" == "" (
  set COMMAND=release
)

if "%COMMAND%" == "release" (
	cmake -B %BUILD_DIR% && cd %BUILD_DIR% && cmake --build . --target install --config Release
) else if "%COMMAND%" == "debug" (
	cmake -B %BUILD_DIR% && cd %BUILD_DIR% && cmake --build . --target install --config Debug
) else if "%COMMAND%" == "clean" (
	cd %BUILD_DIR% && cmake --build . --target install --config Clean
) else if "%COMMAND%" == "test" (
	cd %BUILD_DIR% && ctest --config Release
) else if "%COMMAND%" == "update" (
	%PYTHON% src/cmake/make_update.py
) else if "%COMMAND%" == "format" (
	%PYTHON% src/cmake/make_format.py
) else (
  echo Command "%COMMAND%" unknown
)
