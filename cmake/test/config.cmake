include(${CMAKE_CURRENT_LIST_DIR}/compare.cmake)


function(setup_gemini_test testname TIMEOUT)

# --- setup test
set(outdir ${PROJECT_BINARY_DIR}/test${testname})
set(refroot ${PROJECT_SOURCE_DIR}/test_data)
set(refdir ${refroot}/test${testname})

add_test(NAME gemini:${testname}:setup
  COMMAND ${CMAKE_COMMAND} -Dtestname=${testname} -Doutdir:PATH=${outdir} -Drefroot:PATH=${refroot} -P ${CMAKE_CURRENT_LIST_DIR}/download.cmake)
set_tests_properties(gemini:${testname}:setup PROPERTIES
  FIXTURES_SETUP ${testname}_setup
  FIXTURES_REQUIRED gemini_exe_fix
  TIMEOUT 180)

# construct command
set(test_cmd $<TARGET_FILE:gemini3d.run> ${outdir} -gemexe $<TARGET_FILE:gemini.bin>)

if(mpi)
  list(APPEND test_cmd -mpiexec ${MPIEXEC_EXECUTABLE})

  if(NOT HWLOC_FOUND)
    # hwloc is probably the most accurate way to determine CPU count--fallback to CMake count.
    list(APPEND test_cmd -n ${Ncpu})
  endif()
endif()



if(hdf5)

add_test(NAME gemini:hdf5:${testname}:dryrun
  COMMAND ${test_cmd} -dryrun)
# we prefer default WorkingDirectory of PROJECT_BINARY_DIR to make MSIS 2.0 msis20.parm use simpler
# otherwise, we have to generate source for msis_interface.f90

set_tests_properties(gemini:hdf5:${testname}:dryrun PROPERTIES
  TIMEOUT 60
  RESOURCE_LOCK cpu_mpi
  FIXTURES_REQUIRED ${testname}_setup
  FIXTURES_SETUP hdf5:${testname}:dryrun
  REQUIRED_FILES ${outdir}/inputs/config.nml)


add_test(NAME gemini:hdf5:${testname} COMMAND ${test_cmd})

set_tests_properties(gemini:hdf5:${testname} PROPERTIES
  TIMEOUT ${TIMEOUT}
  RESOURCE_LOCK cpu_mpi
  FIXTURES_REQUIRED hdf5:${testname}:dryrun
  FIXTURES_SETUP hdf5:${testname})

endif(hdf5)


if(netcdf)
add_test(NAME gemini:netcdf:${testname}:dryrun
  COMMAND ${test_cmd} -out_format nc -dryrun)

set_tests_properties(gemini:netcdf:${testname}:dryrun PROPERTIES
  TIMEOUT 60
  RESOURCE_LOCK cpu_mpi
  FIXTURES_REQUIRED "mumps_fixture;${testname}_setup"
  FIXTURES_SETUP netcdf:${testname}:dryrun
  REQUIRED_FILES ${outdir}/inputs/config.nml)

add_test(NAME gemini:netcdf:${testname}
  COMMAND ${test_cmd} -out_format nc)

set_tests_properties(gemini:netcdf:${testname} PROPERTIES
  TIMEOUT ${TIMEOUT}
  RESOURCE_LOCK cpu_mpi
  FIXTURES_REQUIRED netcdf:${testname}:dryrun
  FIXTURES_SETUP netcdf:${testname})
endif(netcdf)

compare_gemini_output(${testname} ${outdir} ${refdir})

endfunction(setup_gemini_test)
