# find_package(px <version>): the same major, at least <version>. In 0.x a
# minor bump may break, so the minor must match too.
include("${CMAKE_CURRENT_LIST_DIR}/version.cmake")
set(PACKAGE_VERSION ${PX_VERSION})
string(REPLACE "." ";" parts "${PX_VERSION}")
list(GET parts 0 major)
list(GET parts 1 minor)

set(PACKAGE_VERSION_COMPATIBLE FALSE)
if(NOT PACKAGE_FIND_VERSION)
  set(PACKAGE_VERSION_COMPATIBLE TRUE)
elseif(PACKAGE_FIND_VERSION VERSION_LESS_EQUAL PX_VERSION
       AND PACKAGE_FIND_VERSION_MAJOR EQUAL major
       AND (major GREATER 0 OR PACKAGE_FIND_VERSION_MINOR EQUAL minor))
  set(PACKAGE_VERSION_COMPATIBLE TRUE)
endif()
if(PACKAGE_FIND_VERSION VERSION_EQUAL PX_VERSION)
  set(PACKAGE_VERSION_EXACT TRUE)
endif()
