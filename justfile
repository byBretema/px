set shell := ["bash", "-ceu"]

# --- Options ---

# Defaults to the last configured preset (see _active).
preset := `p="$(sed -n 1p .build/active_preset 2>/dev/null || true)"; echo "${p:-debug}"`
config_flags := '' # --fresh
build_flags := '' # --clean-first
cpu_usage := '80'

# --- Default ---

[private]
default:
    @just list

# --- Functions ---

_print_list title items:
    @echo "{{ title }}:"
    @[[ -n "{{ items }}" ]] && echo "    {{ replace(items, "\n", "\n    ") }}"
    @echo

_num_of_jobs:
    @cores="$(nproc 2>/dev/null || getconf _NPROCESSORS_ONLN 2>/dev/null || echo 4)"; \
    echo $(( (cores * {{ cpu_usage }} + 99) / 100 ))

# --- Auto vars ---

_root := justfile_directory()

_build_dir := _root / '.build'
_active := _build_dir / 'active_preset'
_cache_dir := _root / '.cache'
_deps_dir := _root / '.deps'

_projects := `shopt -s nullglob; for d in projects/*/; do [ -f "$d/CMakeLists.txt" ] && basename "$d"; done`
_tests := `   shopt -s nullglob; for d in tests/*/;    do [ -f "$d/CMakeLists.txt" ] && basename "$d"; done`

# --- Env ---

export NINJA_STATUS := "[%p] "

# --- List ---

#  all += presets
list *target:
    @echo
    @just _list_{{ target }}
    @just -l -u

_list_:
    @just _print_list "Available projects" "{{ _projects }}"
    @just _print_list "Available tests" "{{ _tests }}"

_list_all:
    @just _list_
    @echo "Available presets (* active):"
    @cd "{{ _root }}" && cmake --list-presets 2>/dev/null | awk -F'"' '/^[[:space:]]+"/ {print $2}' | while read -r p; do [ "$p" = "{{ preset }}" ] && echo "  * $p" || echo "    $p"; done
    @echo

# --- Config ---

# Always configures (e.g. after editing CMakePresets.json)
config:
    @echo
    @echo "- - - - - - - - - - - - - - - - - [  CONFIG ] - - - - - - - - - - - - - - - - -"
    @cmake -S "{{ _root }}" --preset {{ preset }} {{ config_flags }}

# Configures only on first use, preset switch or config_flags; otherwise
# `cmake --build` re-runs CMake by itself when CMake files change.
[private]
_config:
    #!/usr/bin/env bash
    set -eu
    active="$(sed -n 1p "{{ _active }}" 2>/dev/null || true)"
    dir="$(sed -n 2p "{{ _active }}" 2>/dev/null || true)"
    if [[ "{{ preset }}" == "$active" && -f "$dir/CMakeCache.txt" && -z "{{ config_flags }}" ]]; then
        exit 0
    fi
    just preset="{{ preset }}" config_flags="{{ config_flags }}" config

# --- Per target ---

# list... / empty == all
[no-exit-message]
build *targets: _config
    #!/usr/bin/env bash
    set -eu;
    echo
    echo "- - - - - - - - - - - - - - - - - [  BUILD  ] - - - - - - - - - - - - - - - - -"
    echo

    cmake_args=()
    [[ -n "{{ build_flags }}" ]] && cmake_args+=({{ build_flags }})
    [[ -n "{{ targets }}"     ]] && cmake_args+=(--target {{ targets }})
    cmake --build --preset {{ preset }} -j "$(just _num_of_jobs)" "${cmake_args[@]}"

[no-exit-message]
run target *args: (build target)
    #!/usr/bin/env bash
    set -eu;
    echo
    echo "- - - - - - - - - - - - - - - - - [   RUN   ] - - - - - - - - - - - - - - - - -"
    echo
    # Path written by CMake (make_exe/make_test).
    bin="$(cat "$(sed -n 2p "{{ _active }}")/exe/{{ target }}" 2>/dev/null || true)"
    if [[ -z "$bin" ]]; then
        echo "no executable found for target '{{ target }}'"
        exit 1
    fi
    "$bin" {{ args }}

# list... / empty == all
test *tests: (build tests)
    #!/usr/bin/env bash
    set -euo pipefail; echo
    regex=""
    if [[ -n "{{ tests }}" ]]; then
        regex="^({{ replace(tests, ' ', '|') }})$"
    fi
    args=(--preset {{ preset }})
    if [[ -n "$regex" ]]; then
        args+=(-R "$regex")
    fi
    ctest "${args[@]}" | grep -v "^    Start"

# --- Cleanup ---

# all / build / deps
clean target="build":
    @just _clean_{{ target }}

_clean_build:
    @rm -rf "{{ _build_dir }}"
    @rm -rf "{{ _cache_dir }}"
    @rm -f "{{ _root }}/compile_commands.json"

_clean_deps:
    @rm -rf "{{ _deps_dir }}"

_clean_all:
    @just _clean_build
    @just _clean_deps

# --- Scaffolding ---

add_exe name:
    @if ! echo "{{ name }}" | grep -qE '^[A-Za-z0-9_.-]+$'; then echo "invalid name: {{ name }}"; exit 1; fi
    @if [ -e "{{ _root }}/projects/{{ name }}" ]; then echo "already exists: {{ name }}"; exit 1; fi
    @mkdir -p "{{ _root }}/projects/{{ name }}"
    @printf 'make_exe({{ name }})\n' > "{{ _root }}/projects/{{ name }}/CMakeLists.txt"
    @printf 'int main() {\n    return 0;\n}\n' > "{{ _root }}/projects/{{ name }}/main.cpp"
    @if ! grep -qF "add_subdirectory({{ name }})" "{{ _root }}/projects/CMakeLists.txt"; then printf 'add_subdirectory({{ name }})\n' >> "{{ _root }}/projects/CMakeLists.txt"; fi
    @echo "created exe: {{ name }}"

# SHARED / STATIC
add_lib name type="SHARED":
    @if ! echo "{{ name }}" | grep -qE '^[A-Za-z0-9_.-]+$'; then echo "invalid name: {{ name }}"; exit 1; fi
    @if [ -e "{{ _root }}/projects/{{ name }}" ]; then echo "already exists: {{ name }}"; exit 1; fi
    @mkdir -p "{{ _root }}/projects/{{ name }}"
    @printf 'make_lib({{ name }} {{ type }})\n' > "{{ _root }}/projects/{{ name }}/CMakeLists.txt"
    @printf '#pragma once\n\nnamespace {{ name }} {\n}\n' > "{{ _root }}/projects/{{ name }}/{{ name }}.hpp"
    @printf '#include "{{ name }}.hpp"\n' > "{{ _root }}/projects/{{ name }}/{{ name }}.cpp"
    @if ! grep -qF "add_subdirectory({{ name }})" "{{ _root }}/projects/CMakeLists.txt"; then printf 'add_subdirectory({{ name }})\n' >> "{{ _root }}/projects/CMakeLists.txt"; fi
    @echo "created lib: {{ name }} ({{ type }})"
