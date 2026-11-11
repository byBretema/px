#!/bin/sh
# Makes the current dir a px project, named after it, with new.cmake from the
# same px release:
#     mkdir hello && cd hello && curl -fsSL https://github.com/byBretema/px/releases/latest/download/new.sh | sh
# Arguments go to cmake:
#     ... | sh -s -- -D NAME=<name>
# new.ps1 is the Windows twin: keep both in step.
# The release job pins the URL below to its own release.
set -eu

url=https://github.com/byBretema/px/releases/latest/download/new.cmake

for tool in cmake git curl; do
    if ! command -v "$tool" >/dev/null 2>&1; then
        echo "px: $tool not found; px needs CMake 3.28+ and git (curl to fetch this)" >&2
        exit 1
    fi
done

# new.cmake refuses a non-empty dir without FORCE; ask here, as CMake can't.
# Read from the terminal: stdin is this script, piped in.
force=""
if [ "${*#*FORCE=ON}" = "$*" ] && [ -n "$(ls -A | grep -vx .git || true)" ]; then
    printf "px: %s isn't empty; files named like the template's will be replaced. Continue? [y/N] " "$PWD"
    if ! { read -r answer </dev/tty; } 2>/dev/null; then
        printf "\npx: no terminal to ask on; pass -D FORCE=ON (... | sh -s -- -D FORCE=ON)\n" >&2
        exit 1
    fi
    case "$answer" in
    [yY]*) force="-D FORCE=ON" ;;
    *)
        echo "px: aborted"
        exit 1
        ;;
    esac
fi

script="$(mktemp)"
trap 'rm -f "$script"' EXIT
curl -fsSL "$url" -o "$script"

# $force unquoted: empty, or two words.
cmake "$@" $force -P "$script"
