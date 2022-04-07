Building Cycles
===============

## Table of Contents

* [Quick Setup](#quick-setup)
* [Hydra Render Delegate with USD Repository](#hydra-render-delegate-with-usd-repository)
* [Hydra Render Delegate for Houdini](#hydra-render-delegate-for-houdini)
* [Build System](#build-system)
* [Dependencies](#dependencies)

## Quick Setup

Ensure the following software is installed and available in the PATH:
- Git
- Subversion
- Python 3
- CMake

Quick build setup on Windows, macOS and Linux is as follows:

    git clone git://git.blender.org/cycles.git

    cd cycles
    make update
    make

This will download the Cycles source code, download precompiled libraries, configure CMake, and build.

The resulting binary will be in:

    cycles/build/bin

## Hydra Render Delegate with USD Repository

This will make the render delegate work with usdview and other applications built using the USD repository.

USD includes script to build and install in a specified directory. On Linux, use `--use-cxx11-abi 0` to match Blender and the VFX reference platform.

    git clone https://github.com/PixarAnimationStudios/USD.git
    cd USD
    python3 build_scripts/build_usd.py --use-cxx11-abi 0 <path to USD>

Build Cycles pointing to this directory.

    make BUILD_CMAKE_ARGS="WITH_CYCLES_HYDRA_RENDER_DELEGATE=ON -DPXR_ROOT=<path to USD>"

Test in usdview.

    PYTHONPATH=<path to usd>/lib/python PXR_PLUGINPATH_NAME=<path to cycles>/build/bin <path to USD>/bin/usdview

## Hydra Render Delegate for Houdini

For use in Houdini, Cycles must be built using Houdini's USD libraries.

    make BUILD_CMAKE_ARGS="WITH_CYCLES_HYDRA_RENDER_DELEGATE=ON -DHOUDINI_ROOT=<path to Houdini>"

The path to Houdini depends on the operating system, typically:
- Linux: `/opt/hfsX.Y`
- macOS: `/Applications/Houdini/HoudiniX.Y.ZZZ`
- Windows: `C:/Program Files/Side Effects Software/Houdini X.Y.ZZZ`

Test in Houdini using an environment variable.

    PXR_PLUGINPATH_NAME=<path to cycles>/build/bin houdini

Or copy `build/bin/houdini/packages/cycles.json` to the Houdini packages directory to make it always available.

## Build System

Cycles uses the CMake build system. As an alternative to the `make` wrapper, CMake can be manually configured.

See the CMake configuration to enable and disable various features.

The precompiled libraries are shared with Blender, and will be automatically downloaded from the Blender repository with `make update`. They can also be manually downloaded from:

https://svn.blender.org/svnroot/bf-blender/trunk/lib/

The precompiled libraries are expected to be in a `lib/<platform>` folder next to the `cycles/` source folder.

## Dependencies

Core Cycles has the following required and optional library dependencies. These are all included in precompiled libraries.

Required:
- Boost
- OpenImageIO
- TBB

Optional:
- Alembic
- Embree
- OpenColorIO
- OpenVDB / NanoVDB
- OpenShadingLanguage
- OpenImageDenoise
- USD

For GUI support, the following libraries are required. The SDL library must be manually provided, it's not part of the precompiled libraries.
- OpenGL
- GLEW
- SDL

For GPU rendering support on NVIDIA cards, these need to be downloaded and installed from the NVIDIA website.
- CUDA Toolkit 11 or newer
- OptiX 7.3 SDK or newer
