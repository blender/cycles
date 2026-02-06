#!/usr/bin/env python3
# SPDX-FileCopyrightText: 2025 Blender Authors
#
# SPDX-License-Identifier: GPL-2.0-or-later

import argparse
import subprocess
import sys

def get_submodules():
    """Parse .gitmodules to find submodule paths and URLs."""
    try:
        # Get all paths
        output_paths = subprocess.check_output(['git', 'config', '--file', '.gitmodules', '--get-regexp', 'path'], text=True)
        paths = {}
        for line in output_paths.strip().splitlines():
            key, path = line.split(' ', 1)
            # key is submodule.<name>.path
            parts = key.split('.')
            if len(parts) >= 3:
                name = ".".join(parts[1:-1])
                paths[name] = path
            
        # Get all URLs
        output_urls = subprocess.check_output(['git', 'config', '--file', '.gitmodules', '--get-regexp', 'url'], text=True)
        urls = {}
        for line in output_urls.strip().splitlines():
            key, url = line.split(' ', 1)
            parts = key.split('.')
            if len(parts) >= 3:
                name = ".".join(parts[1:-1])
                urls[name] = url
            
        submodules = []
        for name, path in paths.items():
            # Only update lib/ submodules, but skip lib/legacy/
            if path.startswith('lib/') and not path.startswith('lib/legacy/') and name in urls:
                submodules.append({'path': path, 'url': urls[name]})
        return submodules
    except subprocess.CalledProcessError:
        return []

def get_hash_for_tag(url, tag):
    """Get the commit hash for a tag using git ls-remote."""
    try:
        # Check for the tag specifically in refs/tags/
        ref = f"refs/tags/{tag}"
        output = subprocess.check_output(['git', 'ls-remote', url, ref, f"{ref}^{{}}"], text=True).strip()
        
        if not output:
            # Try as-is in case it's a branch or full ref name
            output = subprocess.check_output(['git', 'ls-remote', url, tag], text=True).strip()

        if output:
            lines = output.splitlines()
            hash_map = {}
            for line in lines:
                parts = line.split('\t')
                if len(parts) == 2:
                    h, r = parts
                    hash_map[r] = h
            
            # Prefer the peeled tag if it exists
            peeled_ref = f"{ref}^{{}}"
            if peeled_ref in hash_map:
                return hash_map[peeled_ref]
            if ref in hash_map:
                return hash_map[ref]
                
            # Fallback to whatever matches the tag name best
            for r, h in hash_map.items():
                if r.endswith(tag):
                    return h
                    
            # Last resort: first line
            return lines[0].split('\t')[0]
    except subprocess.CalledProcessError:
        pass
    return None

def update_submodule_hash(path, commit_hash):
    """Update the submodule hash in the index."""
    try:
        # mode 160000 is for submodules (gitlinks)
        subprocess.check_call(['git', 'update-index', '--cacheinfo', f"160000,{commit_hash},{path}"])
        print(f"Updated {path} to {commit_hash}")
        return True
    except subprocess.CalledProcessError as e:
        print(f"Failed to update {path}: {e}")
        return False

def main():
    parser = argparse.ArgumentParser(description="Update submodule hashes in lib/ to a specific tag without checkout.")
    parser.add_argument("tag", help="The tag to set the submodules to.")
    parser.add_argument("--no-commit", action="store_true", help="Do not commit the changes.")
    args = parser.parse_args()
    
    submodules = get_submodules()
    if not submodules:
        print("No submodules found in lib/ (excluding lib/legacy/) in .gitmodules.")
        sys.exit(1)
        
    any_updated = False
    for sub in submodules:
        print(f"Processing {sub['path']}...")
        commit_hash = get_hash_for_tag(sub['url'], args.tag)
        if commit_hash:
            if update_submodule_hash(sub['path'], commit_hash):
                any_updated = True
        else:
            print(f"Could not find hash for tag '{args.tag}' in {sub['url']}")
            
    if any_updated:
        print("\nSubmodule hashes updated in index.")
        if not args.no_commit:
            commit_msg = f"Lib: update submodules to {args.tag}"
            try:
                # Add the script itself if it's untracked
                subprocess.call(['git', 'add', 'tools/update_lib_submodules.py'])
                
                subprocess.check_call(['git', 'commit', '-m', commit_msg])
                print(f"Committed: {commit_msg}")
            except subprocess.CalledProcessError as e:
                print(f"Failed to commit: {e}")
        else:
            print("Use 'git status' to see changes and 'git commit -m \"Lib: update submodules to {0}\"' to commit them.".format(args.tag))
    else:
        print("\nNo submodules were updated.")

if __name__ == "__main__":
    main()