# this script is to install a recent CMake version
# this handles the most common cases, but doesn't handle corner cases like 64-bit kernel with 32-bit user space
# CMAKE_HOST_SYSTEM_PROCESSOR, CMAKE_HOST_SYSTEM_NAME don't work in CMake script mode
#
#   cmake -P install_cmake.cmake
# will install CMake under the user's home directory.
#
# optionally, specify a specific CMake version like:
#   cmake -Dversion="3.13.5" -P install_cmake.cmake
#
# This script can be used to install CMake >= 2.8.12.2 (e.g. for compatibility tests)
# old CMake versions have broken file(DOWNLOAD)--they just "download" 0-byte files.

cmake_minimum_required(VERSION 3.7)

if(NOT prefix)
  if(WIN32)
    set(prefix $ENV{USERPROFILE})
  else()
    set(prefix $ENV{HOME})
  endif()
endif()

if(NOT version)
  set(version 3.19.4)
endif()

if(version STREQUAL 2.8.12)
  set(version 2.8.12.2)
endif()

set(host https://github.com/Kitware/CMake/releases/download/v${version}/)


function(checkup exe)

get_filename_component(path ${exe} DIRECTORY)
set(ep $ENV{PATH})
if(NOT ep MATCHES ${path})
  message(STATUS "add to environment variable PATH ${path}")
endif()

endfunction(checkup)


if(APPLE)
  message(STATUS "please use Homebrew https://brew.sh to install cmake:  'brew install cmake'
  or use Python  'pip install cmake'")
  return()
elseif(UNIX)
  execute_process(COMMAND uname -m OUTPUT_VARIABLE arch OUTPUT_STRIP_TRAILING_WHITESPACE)

  if(version VERSION_LESS 3.1.0)
    set(stem cmake-${version}-Linux-i386)
  elseif(arch STREQUAL x86_64)
    set(stem cmake-${version}-Linux-x86_64)
  elseif(arch STREQUAL aarch64)
    set(stem cmake-${version}-Linux-aarch64)
  else()
    message(FATAL_ERROR "unknown arch ${arch}.  Try:
      cmake -P ${CMAKE_CURRENT_LIST_DIR}/build_cmake.cmake")
  endif()

  set(name ${stem}.tar.gz)
elseif(WIN32)
  # https://docs.microsoft.com/en-us/windows/win32/winprog64/wow64-implementation-details?redirectedfrom=MSDN#environment-variables
  # CMake doesn't currently have binary downloads for ARM64 or IA64
  set(arch $ENV{PROCESSOR_ARCHITECTURE})

  if(version VERSION_LESS 3.6.0)
    set(stem cmake-${version}-win32-x86)
  elseif(arch STREQUAL AMD64)
    set(stem cmake-${version}-win64-x64)
  elseif(arch STREQUAL x86)
    set(stem cmake-${version}-win32-x86)
  else()
    message(FATAL_ERROR "unknown arch ${arch}.  Try:
      cmake -P ${CMAKE_CURRENT_LIST_DIR}/build_cmake.cmake")
  endif()

  set(name ${stem}.zip)
endif()

if(NOT stem)
  message(FATAL_ERROR "unknown CPU arch ${arch}.  Try building CMake from source: 'cmake -P ${CMAKE_CURRENT_LIST_DIR}/build_cmake.cmake'")
endif()

get_filename_component(prefix ${prefix} ABSOLUTE)
set(path ${prefix}/${stem})

find_program(cmake NAMES cmake PATHS ${path} PATH_SUFFIXES bin NO_DEFAULT_PATH)
if(cmake)
  message(STATUS "CMake ${version} already at ${cmake}")

  checkup(${cmake})
  return()
endif()

message(STATUS "installing CMake ${version} to ${prefix}")

set(archive ${prefix}/${name})

if(CMAKE_VERSION VERSION_GREATER_EQUAL 3.14)  # CMake < 3.7 compatible
  if(EXISTS ${archive})
    file(SIZE ${archive} fsize)
    if(fsize LESS 1000000)
      file(REMOVE ${archive})
    endif()
  endif()
endif()

if(NOT EXISTS ${archive})
  set(url ${host}${name})
  message(STATUS "download ${url}")
  file(DOWNLOAD ${url} ${archive} TLS_VERIFY ON)

  if(CMAKE_VERSION VERSION_GREATER_EQUAL 3.14)
    file(SIZE ${archive} fsize)
    if(fsize LESS 1000000)
      message(FATAL_ERROR "failed to download ${url}")
    endif()
  endif()
endif()

message(STATUS "extracting to ${path}")
if(CMAKE_VERSION VERSION_GREATER_EQUAL 3.18)
  file(ARCHIVE_EXTRACT INPUT ${archive} DESTINATION ${prefix})
else()
  execute_process(COMMAND ${CMAKE_COMMAND} -E tar xf ${archive} WORKING_DIRECTORY ${prefix})
endif()

find_program(cmake NAMES cmake PATHS ${path} PATH_SUFFIXES bin NO_DEFAULT_PATH)
if(NOT cmake)
  message(FATAL_ERROR "failed to install CMake from ${archive}")
endif()

checkup(${cmake})
