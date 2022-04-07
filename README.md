Cycles Renderer
===============

Cycles is a path tracing renderer focused on interactivity and ease of use, while supporting many production features.

https://www.cycles-renderer.org

## Building

Cycles can be built as a standalone application or a Hydra render delegate. See [BUILDING.md](BUILDING.md) for instructions.

## Examples

The repository contains example xml scenes which could be used for testing.

Example usage:

    ./cycles scene_monkey.xml

You can also use optional parameters (see `./cycles --help`), like:

    ./cycles --samples 100 --output ./image.png scene_monkey.xml

For the OSL scene you need to enable the OSL shading system:

    ./cycles --shadingsys osl scene_osl_stripes.xml

## Contact

For help building or running Cycles, see the channels listed here:

https://www.cycles-renderer.org/development/
