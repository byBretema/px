cmake_minimum_required(VERSION 3.28)
project(px_version NONE)

find_package(px ${REQUEST} REQUIRED CONFIG PATHS "${CMAKE_CURRENT_LIST_DIR}/../../../framework" NO_DEFAULT_PATH)
