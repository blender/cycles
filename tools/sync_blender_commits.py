#!/usr/bin/env python3
# SPDX-FileCopyrightText: 2023 Blender Authors
#
# SPDX-License-Identifier: GPL-2.0-or-later

import collections
import os
import pathlib
import subprocess
import sys

# Hashes to be ignored
#
# The system sometimes fails to match commits and suggests to back-port
# revision which was already ported. In order to solve that we can:
#
# - Explicitly ignore some of the commits.
# - Move the synchronization point forward.
IGNORE_HASHES = {}

# Start revisions from both repositories.
CYCLES_START_COMMIT = "main"
BLENDER_START_COMMIT = "f701e57"

# Prefix which is common for all the subjects.
GIT_SUBJECT_COMMON_PREFIX = "Subject: [PATCH] "

# Marker which indicates begin of new file in the patch set.
GIT_FILE_SECTION_MARKER = "diff --git"

# Marker of the end of the patch-set.
GIT_PATCHSET_END_MARKER = "-- "

# Prefix of topic to be omitted
SUBJECT_SKIP_PREFIX = (
    "Cycles: ",
    "cycles: ",
    "Cycles Standalone: ",
    "Cycles standalone: ",
    "cycles standalone: ",
)


def subject_strip(common_prefix, subject):
    for prefix in SUBJECT_SKIP_PREFIX:
        full_prefix = common_prefix + prefix
        if subject.startswith(full_prefix):
            subject = subject[len(full_prefix) :].capitalize()
            subject = common_prefix + subject
            break
    return subject


def replace_file_prefix(path, prefix, replace_prefix):
    tokens = path.split(" ")
    prefix_len = len(prefix)
    for i, t in enumerate(tokens):
        for x in ("a/", "b/"):
            if t.startswith(x + prefix):
                tokens[i] = x + replace_prefix + t[prefix_len + 2 :]
    return " ".join(tokens)


def cleanup_patch(patch, accept_prefix, replace_prefix):
    assert accept_prefix[0] != "/"
    assert replace_prefix[0] != "/"

    full_accept_prefix = GIT_FILE_SECTION_MARKER + " a/" + accept_prefix

    with open(patch, "r") as f:
        content = f.readlines()

    clean_content = []
    do_skip = False
    for line in content:
        if line.startswith(GIT_SUBJECT_COMMON_PREFIX):
            # Skip possible prefix like "Cycles:", we already know change is
            # about Cycles since it's being committed to a Cycles repository.
            line = subject_strip(GIT_SUBJECT_COMMON_PREFIX, line)

            # Dots usually are omitted in the topic
            line = line.replace(".\n", "\n")
        elif line.startswith(GIT_FILE_SECTION_MARKER):
            if not line.startswith(full_accept_prefix):
                do_skip = True
            else:
                do_skip = False
                line = replace_file_prefix(line, accept_prefix, replace_prefix)
        elif line.startswith(GIT_PATCHSET_END_MARKER):
            do_skip = False
        elif line.startswith("---") or line.startswith("+++"):
            line = replace_file_prefix(line, accept_prefix, replace_prefix)

        if not do_skip:
            clean_content.append(line)

    with open(patch, "w") as f:
        f.writelines(clean_content)


# Get mapping from commit subject to commit hash.
#
# It'll actually include timestamp of the commit to the map key, so commits with
# the same subject wouldn't conflict with each other.
def commit_map_get(repository, path, start_commit):
    command = (
        "git",
        "--git-dir=" + str(repository / ".git"),
        "--work-tree=" + str(repository),
        "log",
        "--format=%H %at %s",
        "--reverse",
        start_commit + "..HEAD",
        "--",
        repository / path,
        ":(exclude)" + str(repository / "intern/cycles/blender"),
    )
    lines = subprocess.check_output(command, encoding="utf-8").split("\n")
    commit_map = collections.OrderedDict()
    for line in lines:
        if line:
            commit_sha, stamped_subject = line.split(" ", 1)
            stamp, subject = stamped_subject.split(" ", 1)
            subject = subject_strip("", subject).rstrip(".")
            stamped_subject = stamp + " " + subject

            if commit_sha in IGNORE_HASHES:
                continue
            commit_map[stamped_subject] = commit_sha
    return commit_map


# Get difference between two lists of commits.
# Returns two lists: first are the commits to be ported from Cycles to Blender,
# second one are the commits to be ported from Blender to Cycles.
def commits_get_difference(cycles_map, blender_map):
    cycles_to_blender = []
    for stamped_subject, commit_hash in cycles_map.items():
        if stamped_subject not in blender_map:
            cycles_to_blender.append(commit_hash)

    blender_to_cycles = []
    for stamped_subject, commit_hash in blender_map.items():
        if stamped_subject not in cycles_map:
            blender_to_cycles.append(commit_hash)

    return cycles_to_blender, blender_to_cycles


# Transfer commits from one repository to another.
# Doesn't do actual commit just for the safety.
def transfer_commits(commit_hashes, from_repository, to_repository, dst_is_cycles):
    patch_index = 1
    for commit_hash in commit_hashes:
        command = (
            "git",
            "--git-dir=" + str(from_repository / ".git"),
            "--work-tree=" + str(from_repository),
            "format-patch",
            "-1",
            "--start-number",
            str(patch_index),
            "-o",
            to_repository,
            commit_hash,
            "--",
            ":(exclude)" + str(from_repository / "intern/cycles/blender"),
        )
        patch_file = subprocess.check_output(command, encoding="utf-8").rstrip("\n")
        if dst_is_cycles:
            cleanup_patch(patch_file, "intern/cycles", "src")
        else:
            cleanup_patch(patch_file, "src", "intern/cycles")
        patch_index += 1


def main():
    if len(sys.argv) != 2:
        print("Usage: %s /path/to/blender/" % sys.argv[0])
        return

    cycles_repository = pathlib.Path(os.path.abspath(__file__)).parent.parent
    blender_repository = pathlib.Path(sys.argv[1])

    cycles_map = commit_map_get(cycles_repository, "", CYCLES_START_COMMIT)
    blender_map = commit_map_get(
        blender_repository, "intern/cycles", BLENDER_START_COMMIT
    )
    diff = commits_get_difference(cycles_map, blender_map)

    transfer_commits(diff[0], cycles_repository, blender_repository, False)
    transfer_commits(diff[1], blender_repository, cycles_repository, True)

    print("Missing commits were saved to the blender and cycles repositories.")
    print("Check them and if they're all fine run:")
    print("")
    print("  ./tools/sync_git_am.py *.patch")


if __name__ == "__main__":
    main()
