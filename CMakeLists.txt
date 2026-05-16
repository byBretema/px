cmake_minimum_required(VERSION 3.28)

include(vendor/nest.cmake)
project(${nest_TOPNAME})

nest_INIT(20)

nest_ADD_DEP(glm 1.0.3 https://github.com/g-truc/glm/archive/refs/tags/1.0.3.zip OFF)
nest_ADD_DEP(glfw 3.4 https://github.com/glfw/glfw/archive/refs/tags/3.4.zip OFF)

nest_DETECT_PROJECTS()

# add_subdirectory(mylib1)
# add_subdirectory(demo2)
