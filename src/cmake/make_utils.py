#!/usr/bin/env python3
#
# Utility functions for make update and make tests.

import os
import re
import shutil
import subprocess
import sys


def call(cmd, exit_on_error=True):
    print(" ".join(cmd))

    # Flush to ensure correct order output on Windows.
    sys.stdout.flush()
    sys.stderr.flush()

    retcode = subprocess.call(cmd)
    if exit_on_error and retcode != 0:
        sys.exit(retcode)
    return retcode


def check_output(cmd, exit_on_error=True):
    # Flush to ensure correct order output on Windows.
    sys.stdout.flush()
    sys.stderr.flush()

    try:
        output = subprocess.check_output(cmd, stderr=subprocess.STDOUT, universal_newlines=True)
    except subprocess.CalledProcessError as e:
        if exit_on_error:
            sys.stderr.write(" ".join(cmd))
            sys.stderr.write(e.output + "\n")
            sys.exit(e.returncode)
        output = ""

    return output.strip()


def svn_libraries_version():
    def _parse_header_file(filename, define):
        import re
        regex = re.compile(r"^#\s*define\s+%s\s+(.*)" % define)
        with open(filename, "r") as file:
            for l in file:
                match = regex.match(l)
                if match:
                    return match.group(1)
        return None

    return  _parse_header_file(os.path.join("src", "util", "version.h"), "CYCLES_BLENDER_LIBRARIES_VERSION")


def svn_libraries_base_url():
    release_version = svn_libraries_version()
    if release_version:
        svn_branch = "tags/blender-" + release_version + "-release"
    else:
        svn_branch = svn_libraries_version()
    return "https://svn.blender.org/svnroot/bf-blender/" + svn_branch + "/lib/"


def command_missing(command):
    # Support running with Python 2 for macOS
    if sys.version_info >= (3, 0):
        return shutil.which(command) is None
    else:
        return False
