#!/usr/bin/env python3
#
# "make update" for all platforms, updating libraries and Cycles
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
from pathlib import Path
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
    parser.add_argument("--legacy", action="store_true")
    parser.add_argument("--git-command", default="git")
    parser.add_argument("--architecture", type=str,
                        choices=("x86_64", "amd64", "arm64",))
    return parser.parse_args()


def get_effective_platform(args: argparse.Namespace) -> str:
    # Get platform of the host, with standard Blender naming.
    if sys.platform == "darwin":
        platform = "macos"
    elif sys.platform == "win32":
        platform = "windows"
    else:
        platform = sys.platform

    assert (platform in ("linux", "macos", "windows"))

    return platform


def get_effective_architecture(args: argparse.Namespace) -> str:
    # Get architecture of the host, with standard Blender naming.
    architecture: Optional[str] = args.architecture
    if architecture:
        assert isinstance(architecture, str)
    elif "ARM64" in platform.version():
        # Check platform.version to detect arm64 with x86_64 python binary.
        architecture = "arm64"
    else:
        architecture = platform.machine().lower()

    # Normalize the architecture name.
    if architecture in {"x86_64", "amd64"}:
        architecture = "x64"

    assert (architecture in {"x64", "arm64"})
    assert isinstance(architecture, str)

    return architecture


def ensure_git_lfs(args: argparse.Namespace) -> None:
    # Use `--skip-repo` to avoid creating git hooks.
    # This is called from the `blender.git` checkout, so we don't need to install hooks there.
    call((args.git_command, "lfs", "install", "--skip-repo"), exit_on_error=True)


def libraries_update(args: argparse.Namespace) -> None:
    # Configure and update submodule for precompiled libraries
    platform = get_effective_platform(args)
    arch = get_effective_architecture(args)

    print(f"Detected platform     : {platform}")
    print(f"Detected architecture : {arch}")
    print()

    if args.legacy:
        submodule_dir = Path(f"lib/legacy/{platform}_{arch}")
    else:
        submodule_dir = Path(f"lib/{platform}_{arch}")

    make_utils.git_enable_submodule(args.git_command, submodule_dir)
    make_utils.git_update_submodule(args.git_command, submodule_dir)


# Test if git repo can be updated.
def git_update_skip(args: argparse.Namespace, check_remote_exists=True) -> str:
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

    if not args.no_cycles:
        cycles_skip_msg = git_update_skip(args)
        if cycles_skip_msg:
            cycles_skip_msg = "Cycles repository skipped: " + cycles_skip_msg + "\n"
        else:
            cycles_update(args)

    if not args.no_libraries:
        libraries_update(args)

    # Report any skipped repositories at the end, so it's not as easy to miss.
    if cycles_skip_msg:
        print_stage(cycles_skip_msg.strip())
