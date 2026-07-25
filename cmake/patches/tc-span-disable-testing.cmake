file(READ "${${fetch_id}_SOURCE_DIR}/CMakeLists.txt" _content)
string(REGEX REPLACE "\nenable_testing\\(\\)\n" "\n" _content "${_content}")
file(WRITE "${${fetch_id}_SOURCE_DIR}/CMakeLists.txt" "${_content}")
