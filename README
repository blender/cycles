Cycles Renderer
===============

Cycles is a path tracing renderer focused on interactivity and ease of use, while supporting many production features.

https://www.cycles-renderer.org

Quick Build
-----------

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

Build Details
-------------

Cycles uses the CMake build system. As an alternative to the "make" wrapper, CMake can be manually configured.

See the CMake configuration to enable and disable various features.

The precompiled libraries are shared with Blender, and will be automatically downlaod from the Blender repository with "make update" from:
  https://svn.blender.org/svnroot/bf-blender/trunk/lib/

The precompiled libraries are expected to be in a lib/<platform> folder next to the cycles/ source folder.

Dependencies
------------

The following library dependencies are required for building a feature complete Cycles version. These are all included as part of the precompiled libraries.

Required:
- OpenGL
- GLEW
- GLUT
- Boost
- OpenImageIO
- TBB

Optional:
- Embree
- OpenColorIO
- OpenVDB / NanoVDB
- OpenShadingLanguage
- OpenImageDenoise

For GPU rendering support on NVIDIA cards, these need to be downloaded and installed from the NVIDIA website.

- CUDA Toolkit 11 or newer
- OptiX 7.1 SDK

Examples
--------

The repository contains example xml scenes which could be used for testing.

Example usage:

  ./cycles scene_monkey.xml

You can also use optional parameters (see ./cycles --help), like:

  ./cycles --samples 100 --output ./image.png scene_monkey.xml

For the OSL scene you need to enable the OSL shading system:

  ./cycles --shadingsys osl scene_osl_stripes.xml

Contact
-------

For help building or running Cycles, see the channels listed here:

https://www.cycles-renderer.org/development/
