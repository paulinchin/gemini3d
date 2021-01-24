# Finds Lapack, tests, and if not found or broken, autobuild Lapack
include(FetchContent)

if(autobuild)
  find_package(LAPACK)
else()
  find_package(LAPACK REQUIRED)
endif()

if(NOT LAPACK_FOUND)
  set(lapack_external true CACHE BOOL "autobuild Lapack")

  if(GIT_FOUND)
    FetchContent_Declare(LAPACK
      GIT_REPOSITORY ${lapack_git}
      GIT_TAG ${lapack_tag}
      CMAKE_ARGS "-Darith=${arith}")
  else(GIT_FOUND)
    FetchContent_Declare(LAPACK
      URL ${lapack_zip}
      TLS_VERIFY true
      CMAKE_ARGS "-Darith=${arith}")
  endif(GIT_FOUND)

  FetchContent_MakeAvailable(LAPACK)

  add_library(LAPACK::LAPACK ALIAS lapack)
  add_library(BLAS::BLAS ALIAS blas)
endif()
