# installs Gemini3D basic prereqs on Linux and MacOS, and Windows with MSYS2
# use by:
#
#  cmake -P scripts/gemini_prereq.cmake

if(WIN32)
  message(FATAL_ERROR "Please install Gemini prereqs on Winows via MSYS2 Terminal https://www.msys2.org/")
endif()

execute_process(COMMAND uname -s OUTPUT_VARIABLE id TIMEOUT 5)

if(id MATCHES "MSYS")
  execute_process(COMMAND pacman -S --needed mingw-w64-x86_64-gcc-fortran mingw-w64-x86_64-ninja mingw-w64-x86_64-hwloc mingw-w64-x86_64-msmpi mingw-w64-x86_64-hdf5 mingw-w64-x86_64-lapack mingw-w64-x86_64-scalapack mingw-w64-x86_64-mumps)
elseif(APPLE)
  find_program(brew
    NAMES brew
    PATHS /usr/local /opt/homeebrew
    PATH_SUFFIXES bin)

  if(NOT brew)
    message(FATAL_ERROR "We generally suggest installing Homebrew package manager https://brew.sh")
  endif()

  execute_process(COMMAND ${brew} install gcc ninja cmake hwloc lapack scalapack openmpi hdf5)
else()
  find_program(apt NAMES apt)
  if(apt)
    execute_process(COMMAND apt install --no-install-recommends gfortran libhwloc-dev libmumps-dev liblapack-dev libscalapack-mpi-dev libopenmpi-dev openmpi-bin libhdf5-dev)
    return()
  endif()

  find_program(yum NAMES yum)
  if(yum)
    execute_process(COMMAND yum install epel-release gcc-gfortran hwloc-devel MUMPS-openmpi-devel lapack-devel scalapack-openmpi-devel openmpi-devel hdf5-devel)
    return()
  endif()

  find_program(pacman NAMES pacman)
  if(pacman)
    execute_process(COMMAND pacman -S --needed gcc-fortran ninja hwloc openmpi hdf5 lapack scalapack mumps)
    return()
  endif()
endif()


endif()
