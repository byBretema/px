set shell := ["bash", "-ceu"]

# --- Options ---

preset := 'debug'
generator := 'Ninja'
config_flags := '' # --fresh
build_flags := '' # --clean-first
export cpu_usage := '80'

# --- Default ---

default:
    @just list "base"

# --- Functions ---

_print_list title items:
    @echo "{{ title }}:"
    @if [[ -n "{{ items }}" ]]; then echo "    {{ replace(items, "\n", "\n    ") }}"; fi
    @echo

# --- Auto vars ---

_root := justfile_directory()

_build_dir := _root / '.build'

_projects := `shopt -s nullglob; for d in projects/*/; do [ -f "$d/CMakeLists.txt" ] && basename "$d"; done`
_tests := `   shopt -s nullglob; for d in tests/*/;    do [ -f "$d/CMakeLists.txt" ] && basename "$d"; done`

_extra_config_flags := if path_exists(_build_dir) == "true" { "" } else { "--fresh" }

_cores := `nproc 2>/dev/null || getconf _NPROCESSORS_ONLN 2>/dev/null`
_jobs := if _cores != "" { `echo $(( ({{ _cores }} * {{ cpu_usage }} + 99) / 100 ))` } else { "4" }

# --- Env ---

export CCACHE_DIR := _root / '.cache' / 'ccache'
export DEPS_DIR := _root / '.deps'

export NINJA_STATUS := "[%p] "

# --- List ---

list target="base":
    @echo
    @just _list_{{ target }}
    @just -l -u

_list_base:
    @just _print_list "Available projects" "{{ _projects }}"
    @just _print_list "Available tests" "{{ _tests }}"

_list_all:
    @just _list_base
    @echo "Available presets:"
    @cd "{{ _root }}" && cmake --list-presets 2>/dev/null | awk -F'"' '/^[[:space:]]+"/ {print $2}' | while read -r p; do [ -n "$p" ] && echo "    $p"; done
    @echo

# --- Config ---

[private]
config:
    @cmake -E make_directory "{{ _build_dir }}"
    @cmake -S "{{ _root }}" -B "{{ _build_dir }}" -G "{{ generator }}" \
        --preset {{ preset }} {{ config_flags }} {{ _extra_config_flags }}

# --- Per target ---

# all / target
[no-exit-message]
build *targets: config
    @echo
    @cmake --build "{{ _build_dir }}" -j "{{ _jobs }}" {{ build_flags }} \
        {{ if targets == "" { "" } else if targets == "all" { "" } else { " --target " + targets } }}

[no-exit-message]
run target *args: (build target)
    #!/usr/bin/env bash
    set -eu; echo
    bin="$(find "{{ _build_dir }}" -type f -name "{{ target }}" -perm -u+x 2>/dev/null | head -1)"
    if [[ -z "$bin" ]]; then
        echo "no executable found for target '{{ target }}'"
        exit 1
    fi
    "$bin" {{ args }}

# space-separated runs multiple, empty runs all
test *tests:
    #!/usr/bin/env bash
    set -eu; echo; echo "Building & running tests..."
    just build "{{ tests }}"
    regex=""
    if [[ -n "{{ tests }}" ]]; then
        regex="^({{ replace(tests, ' ', '|') }})$"
    fi
    args=(--test-dir "{{ _build_dir }}" --output-on-failure --parallel 8 -C {{ preset }})
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
    @rm -rf "{{ CCACHE_DIR }}"
    @rm -f "{{ _root }}/compile_commands.json"

_clean_deps:
    @rm -rf "{{ DEPS_DIR }}"

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
    @if ! grep -qF "add_subdirectory({{ name }})" "{{ _root }}/projects/CMakeLists.txt"; then echo "add_subdirectory({{ name }})" >> "{{ _root }}/projects/CMakeLists.txt"; fi
    @echo "created exe: {{ name }}"

# type = SHARED / STATIC
add_lib name type="SHARED":
    @if ! echo "{{ name }}" | grep -qE '^[A-Za-z0-9_.-]+$'; then echo "invalid name: {{ name }}"; exit 1; fi
    @if [ -e "{{ _root }}/projects/{{ name }}" ]; then echo "already exists: {{ name }}"; exit 1; fi
    @mkdir -p "{{ _root }}/projects/{{ name }}"
    @printf 'make_lib({{ name }} {{ type }})\n' > "{{ _root }}/projects/{{ name }}/CMakeLists.txt"
    @printf '#pragma once\n\nnamespace {{ name }} {\n}\n' > "{{ _root }}/projects/{{ name }}/{{ name }}.hpp"
    @printf '#include "{{ name }}.hpp"\n' > "{{ _root }}/projects/{{ name }}/{{ name }}.cpp"
    @if ! grep -qF "add_subdirectory({{ name }})" "{{ _root }}/projects/CMakeLists.txt"; then echo "add_subdirectory({{ name }})" >> "{{ _root }}/projects/CMakeLists.txt"; fi
    @echo "created lib: {{ name }} ({{ type }})"
