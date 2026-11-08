# Logger: log_* macros, PRE_LOG_TAG prefix.

set(PRE_LOG_TAG "" CACHE STRING "Prefix for framework log messages")

macro(__log_msg level)
  if(PRE_LOG_TAG)
    message(${level} "${PRE_LOG_TAG} " ${ARGN})
  else()
    message(${level} ${ARGN})
  endif()
endmacro()

macro(log_ln)
  message("")
endmacro()

macro(log_status)
  __log_msg(STATUS ${ARGN})
endmacro()
macro(log_warning)
  __log_msg(WARNING ${ARGN})
endmacro()
macro(log_error)
  __log_msg(SEND_ERROR ${ARGN})
endmacro()
macro(log_fatal)
  __log_msg(FATAL_ERROR ${ARGN})
endmacro()

macro(log_header)
  log_ln()
  message("[ ${ARGN} ]")
  log_ln()
endmacro()

macro(log_level_to_notice)
  if(DEFINED CMAKE_MESSAGE_LOG_LEVEL)
    set(__saved_log_level "${CMAKE_MESSAGE_LOG_LEVEL}")
  else()
    set(__saved_log_level "STATUS")
  endif()
  set(CMAKE_MESSAGE_LOG_LEVEL "NOTICE")
endmacro()

macro(log_level_restore)
  if(DEFINED __saved_log_level)
    set(CMAKE_MESSAGE_LOG_LEVEL "${__saved_log_level}")
  endif()
  unset(__saved_log_level)
endmacro()


