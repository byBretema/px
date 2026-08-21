set shell := ["bash", "-cu"]

# --- Options ---

preset := 'debug'
generator := 'Ninja'
config_flags := '' # --fresh
build_flags := '' # --clean-first
cpu_usage := '80'

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

_build_dir := _root / 'build'
_ccache_dir := _root / '.cache' / 'ccache'

_projects := `shopt -s nullglob; for d in projects/*/; do [ -f "$d/CMakeLists.txt" ] && basename "$d"; done`
_tests    := `shopt -s nullglob; for d in tests/*/;    do [ -f "$d/CMakeLists.txt" ] && basename "$d"; done`

_extra_config_flags := if path_exists(_build_dir) == "true" { "" } else { "--fresh" }

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
    @cmake                        \
        -S "{{ _root }}"          \
        -B "{{ _build_dir }}"     \
        -G "{{ generator }}"      \
        --preset {{ preset }}     \
        {{ config_flags }}        \
        {{ _extra_config_flags }}

# --- Per target ---

# all / target
[no-exit-message]
build *targets: config
    @echo
    @cores=$(nproc 2>/dev/null || getconf _NPROCESSORS_ONLN 2>/dev/null); \
    if [[ -n "$cores" ]]; then \
        jobs=$(( (cores * {{ cpu_usage }} + 99) / 100 )); \
    else \
        jobs=4; \
    fi; \
    if [[ -z "{{ targets }}" || "{{ targets }}" == "all" ]]; then \
        cmake --build "{{ _build_dir }}" -j "$jobs" {{ build_flags }}; \
    else \
        cmake --build "{{ _build_dir }}" -j "$jobs" {{ build_flags }} --target {{ targets }}; \
    fi

# target [args]
[no-exit-message]
run target *args: (build target)
    @echo
    @bin="$(find "{{ _build_dir }}" -type f -name "{{ target }}" -perm -u+x 2>/dev/null | head -1)"; \
    if [ -z "$bin" ]; then echo "no executable found for target '{{ target }}'"; exit 1; fi; \
    "$bin" {{ args }}

# all / test_name(s) — space-separated runs multiple, empty runs all
test *tests:
    @echo
    @echo "🧪 Building & running tests..."
    @just build "{{ tests }}"
    @r=""; [[ -n "{{ tests }}" ]] && r="^({{ replace(tests, ' ', '|') }})$"; \
    ctest --test-dir "{{ _build_dir }}" \
        --output-on-failure --parallel 8 -C {{ preset }} \
        $( [ -n "$r" ] && echo "-R" "$r" ) \
        | grep -v "^    Start"

# --- Cleanup ---

# all / target / build / external
clean target="projects":
    @just _clean_{{ target }}

_clean_projects:
    @rm -rf "{{ _build_dir }}"
    @rm -rf "{{ _ccache_dir }}"
    @rm -f "{{ _root }}/compile_commands.json"

_clean_all:
    @v="$(sed -n 's/^VENDOR_DIR:PATH=//p' "{{ _build_dir }}/CMakeCache.txt" 2>/dev/null | head -1)" || true; \
    [ -n "$v" ] && rm -rf "$v" || true
    @just _clean_projects

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
