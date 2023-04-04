#!/usr/bin/env python3
#
# "make update" for all platforms, updating svn libraries and Cycles
# git repository.
#
# For release branches, this will check out the appropriate branches of
# libraries.

import argparse
import os
import platform
import shutil
import sys

import make_utils
from make_utils import call, check_output


def print_stage(text):
    print("")
    print(text)
    print("")

# Parse arguments
def parse_arguments():
    parser = argparse.ArgumentParser()
    parser.add_argument("--no-libraries", action="store_true")
    parser.add_argument("--no-cycles", action="store_true")
    parser.add_argument("--svn-command", default="svn")
    parser.add_argument("--git-command", default="git")
    return parser.parse_args()


def get_cycles_git_root():
    return check_output([args.git_command, "rev-parse", "--show-toplevel"])


# Setup for precompiled libraries and tests from svn.
def svn_update(args):
    svn_non_interactive = [args.svn_command, '--non-interactive']

    lib_dirpath = os.path.join(get_cycles_git_root(), '..', 'lib')
    svn_url = make_utils.svn_libraries_base_url()

    # Checkout precompiled libraries
    if sys.platform == 'darwin':
        if platform.machine() == 'x86_64':
            libs_platform = ["darwin"]
        elif platform.machine() == 'arm64':
            libs_platform = ["darwin_arm64"]
        else:
            libs_platform = []
    elif sys.platform == 'win32' and platform.machine() == 'AMD64':
        libs_platform = ["win64_vc15"]
    elif sys.platform == 'linux' and platform.machine() == 'x86_64':
        libs_platform = ["linux_x86_64_glibc_228", "linux_centos7_x86_64"]
    else:
        libs_platform = []

    for lib_platform in libs_platform:
        lib_platform_dirpath = os.path.join(lib_dirpath, lib_platform)

        if not os.path.exists(lib_platform_dirpath):
            print_stage("Checking out Precompiled Libraries")

            if make_utils.command_missing(args.svn_command):
                sys.stderr.write("svn not found, can't checkout libraries\n")
                sys.exit(1)

            svn_url_platform = svn_url + lib_platform
            call(svn_non_interactive + ["checkout", svn_url_platform, lib_platform_dirpath])

    # Update precompiled libraries and tests
    print_stage("Updating Precompiled Libraries")

    if os.path.isdir(lib_dirpath):
        for dirname in os.listdir(lib_dirpath):
            dirpath = os.path.join(lib_dirpath, dirname)

            if dirname == ".svn":
                # Cleanup must be run from svn root directory if it exists.
                if not make_utils.command_missing(args.svn_command):
                    call(svn_non_interactive + ["cleanup", lib_dirpath])
                continue

            svn_dirpath = os.path.join(dirpath, ".svn")
            svn_root_dirpath = os.path.join(lib_dirpath, ".svn")

            if (
                    os.path.isdir(dirpath) and
                    (os.path.exists(svn_dirpath) or os.path.exists(svn_root_dirpath))
            ):
                if make_utils.command_missing(args.svn_command):
                    sys.stderr.write("svn not found, can't update libraries\n")
                    sys.exit(1)

                # Cleanup to continue with interrupted downloads.
                if os.path.exists(svn_dirpath):
                    call(svn_non_interactive + ["cleanup", dirpath])
                # Switch to appropriate branch and update.
                call(svn_non_interactive + ["switch", svn_url + dirname, dirpath], exit_on_error=False)
                call(svn_non_interactive + ["update", dirpath])

# Test if git repo can be updated.
def git_update_skip(args, check_remote_exists=True):
    if make_utils.command_missing(args.git_command):
        sys.stderr.write("git not found, can't update code\n")
        sys.exit(1)

    # Abort if a rebase is still progress.
    rebase_merge = check_output([args.git_command, 'rev-parse', '--git-path', 'rebase-merge'], exit_on_error=False)
    rebase_apply = check_output([args.git_command, 'rev-parse', '--git-path', 'rebase-apply'], exit_on_error=False)
    merge_head = check_output([args.git_command, 'rev-parse', '--git-path', 'MERGE_HEAD'], exit_on_error=False)
    if (
            os.path.exists(rebase_merge) or
            os.path.exists(rebase_apply) or
            os.path.exists(merge_head)
    ):
        return "rebase or merge in progress, complete it first"

    # Abort if uncommitted changes.
    changes = check_output([args.git_command, 'status', '--porcelain', '--untracked-files=no'])
    if len(changes) != 0:
        return "you have unstaged changes"

    # Test if there is an upstream branch configured
    if check_remote_exists:
        branch = check_output([args.git_command, "rev-parse", "--abbrev-ref", "HEAD"])
        remote = check_output([args.git_command, "config", "branch." + branch + ".remote"], exit_on_error=False)
        if len(remote) == 0:
            return "no remote branch to pull from"

    return ""


# Update cycles repository.
def cycles_update(args):
    print_stage("Updating Cycles Git Repository")
    call([args.git_command, "pull", "--rebase"])


if __name__ == "__main__":
    args = parse_arguments()
    cycles_skip_msg = ""

    if not args.no_libraries:
        svn_update(args)
    if not args.no_cycles:
        cycles_skip_msg = git_update_skip(args)
        if cycles_skip_msg:
            cycles_skip_msg = "Cycles repository skipped: " + cycles_skip_msg + "\n"
        else:
            cycles_update(args)

    # Report any skipped repositories at the end, so it's not as easy to miss.
    if cycles_skip_msg:
        print_stage(cycles_skip_msg.strip())
