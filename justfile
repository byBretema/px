set shell := ["bash", "-c"]

# --- Vars ---

root := justfile_directory()

build_root := root / "build"
build_dir := build_root / "build"

_projects := `for d in projects/*/; do if [ -f "$d/CMakeLists.txt" ]; then basename "$d"; fi; done`
_tests := `for d in tests/*/; do if [ -f "$d/CMakeLists.txt" ]; then basename "$d"; fi; done`

fresh_flag := if path_exists(build_dir) == "true" { "" } else { "--fresh" }

parallel := `nproc 2>/dev/null || getconf _NPROCESSORS_ONLN 2>/dev/null || echo 4`
preset := "debug"

generator := "Ninja"

# --- Private ---

[private]
list target="base":
    @just _list_{{ target }}
    @echo
    @just -l -u

[private]
_list_base:
    @echo "Available projects:"
    @echo "{{ _projects }}" | while read -r p; do [ -n "$p" ] && echo "    $p"; done
    @echo
    @echo "Available tests:"
    @echo "{{ _tests }}" | while read -r p; do [ -n "$p" ] && echo "    $p"; done

[private]
_list_all:
    @just _list_base
    @echo
    @echo "Available presets:"
    @cd "{{ root }}" && cmake --list-presets 2>/dev/null | awk -F'"' '/^[[:space:]]+"/ {print $2}' | while read -r p; do [ -n "$p" ] && echo "    $p"; done

[private]
config:
    @cmake -E make_directory "{{ build_dir }}"
    cmake -S "{{ root }}" --preset {{ preset }} -G "{{ generator }}" {{ fresh_flag }}

# --- Scaffolding ---

# Scaffolds a new executable
add_exe name:
    @if ! echo "{{ name }}" | grep -qE '^[A-Za-z0-9_.-]+$'; then echo "invalid name: {{ name }}"; exit 1; fi
    @if [ -e "{{ root }}/projects/{{ name }}" ]; then echo "already exists: {{ name }}"; exit 1; fi
    @mkdir -p "{{ root }}/projects/{{ name }}"
    @printf 'make_exe({{ name }})\n' > "{{ root }}/projects/{{ name }}/CMakeLists.txt"
    @printf 'int main() {\n    return 0;\n}\n' > "{{ root }}/projects/{{ name }}/main.cpp"
    @if ! grep -qF "add_subdirectory({{ name }})" "{{ root }}/projects/CMakeLists.txt"; then echo "add_subdirectory({{ name }})" >> "{{ root }}/projects/CMakeLists.txt"; fi
    @echo "created exe: {{ name }}"

# Scaffolds a new library (type = SHARED / STATIC)
add_lib name type="SHARED":
    @if ! echo "{{ name }}" | grep -qE '^[A-Za-z0-9_.-]+$'; then echo "invalid name: {{ name }}"; exit 1; fi
    @if [ -e "{{ root }}/projects/{{ name }}" ]; then echo "already exists: {{ name }}"; exit 1; fi
    @mkdir -p "{{ root }}/projects/{{ name }}"
    @printf 'make_lib({{ name }} {{ type }})\n' > "{{ root }}/projects/{{ name }}/CMakeLists.txt"
    @printf '#pragma once\n\nnamespace {{ name }} {\n}\n' > "{{ root }}/projects/{{ name }}/{{ name }}.hpp"
    @printf '#include "{{ name }}.hpp"\n' > "{{ root }}/projects/{{ name }}/{{ name }}.cpp"
    @if ! grep -qF "add_subdirectory({{ name }})" "{{ root }}/projects/CMakeLists.txt"; then echo "add_subdirectory({{ name }})" >> "{{ root }}/projects/CMakeLists.txt"; fi
    @echo "created lib: {{ name }} ({{ type }})"

# --- Over targets ---

# targets = all / <project_name> ...
[no-exit-message]
build *targets: config
    @echo
    @if [ -z "{{ targets }}" -o "{{ targets }}" = "all" ]; then \
        cmake --build "{{ build_dir }}" -j {{ parallel }}; \
    else \
        cmake --build "{{ build_dir }}" -j {{ parallel }} --target {{ targets }}; \
    fi

# target = <project_name> executable target
[no-exit-message]
run target *args: (build target)
    @echo
    @bin="$(find "{{ build_dir }}" -type f -name "{{ target }}" -perm -u+x 2>/dev/null | head -1)"; \
    if [ -z "$bin" ]; then echo "no executable found for target '{{ target }}'"; exit 1; fi; \
    "$bin" {{ args }}

# tests = all / test_name(s) — space-separated runs multiple, empty runs all
test *tests:
    @echo
    @echo "🧪 Building & running tests..."
    @just build "{{ tests }}"
    @r=""; [ -n "{{ tests }}" ] && r="^($(echo {{ tests }} | tr ' ' '|'))$"; \
    ctest --test-dir "{{ build_dir }}" \
        --output-on-failure --parallel 8 -C {{ preset }} \
        $( [ -n "$r" ] && echo "-R" "$r" ) \
        | grep -v "^    Start"

# --- Cleanup ---

# target = all / projects  (wipe 'all' or 'projects only')
clean target="projects":
    @just _clean_{{ target }}

[private]
_clean_projects:
    @rm -rf "{{ build_dir }}"
    @rm -rf "{{ root }}/.cache"
    @rm -f "{{ root }}/compile_commands.json"

[private]
_clean_all:
    @v="$(sed -n 's/^VENDOR_DIR:PATH=//p' "{{ build_dir }}/CMakeCache.txt" 2>/dev/null | head -1)" || true; \
    [ -n "$v" ] && rm -rf "$v" || true
    @just _clean_projects
