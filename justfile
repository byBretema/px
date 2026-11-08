set shell := ["bash", "-ceu"]

# Template preset the full projects build with
preset := 'debug-strict'

_build := justfile_directory() / '.build' / 'tests'

[private]
default:
    @just --list

# Fixtures under tests/fixtures: all, or the named ones (e.g. full_project_01)
test *names:
    @cmake -S tests -B "{{ _build }}" -D PX_TEST_PRESET={{ preset }} > /dev/null
    @ctest --test-dir "{{ _build }}" -j 4 --output-on-failure {{ if names == "" { "" } else { '-R "^(' + replace(names, ' ', '|') + ')(_|$)"' } }}
