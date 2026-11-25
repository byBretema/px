set shell := ["bash", "-ceu"]

# Template preset and checks (true / false) template_example_project builds with
preset := 'debug'
strict := 'true'
asan := 'false'
ubsan := 'false'
tsan := 'false'
msan := 'false'
lsan := 'false'

_checks := '-DPX_FORCE_ERRORS=' + strict + ';-DPX_ENABLE_ASAN=' + asan + ';-DPX_ENABLE_UBSAN=' + ubsan + \
    ';-DPX_ENABLE_TSAN=' + tsan + ';-DPX_ENABLE_MSAN=' + msan + ';-DPX_ENABLE_LSAN=' + lsan

_build := justfile_directory() / '.build' / 'tests'

[private]
default:
    @just --list

# Fixtures under tests/fixtures: all, or the named ones (e.g. template_example_project)
test *names:
    @cmake -S tests -B "{{ _build }}" -D PX_TEST_PRESET={{ preset }} -D "PX_TEST_CHECKS={{ _checks }}" > /dev/null
    @ctest --test-dir "{{ _build }}" -j 4 --output-on-failure {{ if names == "" { "" } else { '-R "^(' + replace(names, ' ', '|') + ')(_|$)"' } }}

# Sets the version (framework and template), commits everything as v<version>,
# tags it and pushes both; CI releases it. CHANGELOG.md needs its section first.
publish_tag version:
    #!/usr/bin/env bash
    set -eu
    v="{{ version }}"
    [[ "$v" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo "version must be X.Y.Z, got '$v'" >&2; exit 1; }
    cur="$(sed -n 's/^set(PX_VERSION \(.*\))$/\1/p' framework/version.cmake)"
    [[ "$v" != "$cur" && "$(printf '%s\n' "$cur" "$v" | sort -V | tail -1)" == "$v" ]] \
        || { echo "version $v isn't above the current $cur" >&2; exit 1; }
    grep -qx "## $v" CHANGELOG.md || { echo "CHANGELOG.md has no '## $v' section" >&2; exit 1; }
    ! git rev-parse -q --verify "refs/tags/v$v" >/dev/null || { echo "tag v$v already exists" >&2; exit 1; }
    # Not sed -i: its flag differs between GNU and BSD sed.
    set_var() {
        local tmp; tmp="$(mktemp)"
        sed "s/^set($2 .*)$/set($2 $v)/" "$1" > "$tmp" && cat "$tmp" > "$1"
        grep -qx "set($2 $v)" "$1" || { echo "no 'set($2 ...)' line in $1" >&2; exit 1; }
    }
    set_var framework/version.cmake PX_VERSION
    set_var template/cmake/px.cmake __px_version
    git add -A
    git commit -m "v$v"
    git tag -a "v$v" -m "px $v"
    git push --atomic origin HEAD "v$v"
