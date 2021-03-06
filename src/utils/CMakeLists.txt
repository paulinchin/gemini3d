include(CheckSymbolExists)
include(CheckIncludeFile)

add_library(helpmod OBJECT help.f90)
target_link_libraries(helpmod PRIVATE config)
set_target_properties(helpmod PROPERTIES Fortran_MODULE_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/include)
target_include_directories(helpmod INTERFACE ${CMAKE_CURRENT_BINARY_DIR}/include)

#--------magnetic field calculation executable---------------
configure_file(magcalc_cli.in.f90 magcalc_cli.f90 @ONLY)
add_executable(magcalc.bin)
target_sources(magcalc.bin PRIVATE magcalc.f90 ${CMAKE_CURRENT_BINARY_DIR}/magcalc_cli.f90
$<TARGET_OBJECTS:autogrid>)
target_link_libraries(magcalc.bin PRIVATE helpmod config const grid io mesh mpimod pathlib reader sanity_check timeutils h5fortran::h5fortran)
set_target_properties(magcalc.bin PROPERTIES RUNTIME_OUTPUT_DIRECTORY ${PROJECT_BINARY_DIR})

add_test(NAME unit:magcalc_exe_ok COMMAND $<TARGET_FILE:magcalc.bin>)
set_tests_properties(unit:magcalc_exe_ok PROPERTIES PASS_REGULAR_EXPRESSION "EOF: magcalc.bin")

# --- gemini3d.run Fortran front end
add_subdirectory(hwloc)

configure_file(gemini3d_run.in.f90 gemini3d_run.f90 @ONLY)
add_executable(gemini3d.run)
target_sources(gemini3d.run PRIVATE ${CMAKE_CURRENT_BINARY_DIR}/gemini3d_run.f90 runner.f90)
target_link_libraries(gemini3d.run PRIVATE const helpmod hwloc_ifc hwloc_c config pathlib timeutils autogrid reader h5fortran::h5fortran nc4fortran::nc4fortran)
if(HWLOC_FOUND)
  target_link_libraries(gemini3d.run PRIVATE HWLOC::HWLOC)
endif()
set_target_properties(gemini3d.run PROPERTIES RUNTIME_OUTPUT_DIRECTORY ${PROJECT_BINARY_DIR})
set_target_properties(gemini3d.run PROPERTIES Fortran_MODULE_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/include)

add_test(NAME unit:gemini3d_run_ok COMMAND $<TARGET_FILE:gemini3d.run>)
set_tests_properties(unit:gemini3d_run_ok PROPERTIES
  PASS_REGULAR_EXPRESSION "EOF: gemini3d.run"
  DEPENDS unit:HWLOC)

# --- Gemini compare

add_library(assert assert.f90)
target_include_directories(assert INTERFACE ${CMAKE_CURRENT_BINARY_DIR}/include)
set_target_properties(assert PROPERTIES Fortran_MODULE_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/include)


add_executable(gemini3d.compare)
target_sources(gemini3d.compare PRIVATE gemini_compare.f90 ${CMAKE_CURRENT_SOURCE_DIR}/../io/compare.f90)
target_link_libraries(gemini3d.compare PRIVATE assert config reader pathlib timeutils const nc4fortran::nc4fortran h5fortran::h5fortran)
target_include_directories(gemini3d.compare PRIVATE ${CMAKE_CURRENT_BINARY_DIR}/include)
set_target_properties(gemini3d.compare PROPERTIES
  RUNTIME_OUTPUT_DIRECTORY ${PROJECT_BINARY_DIR}
  Fortran_MODULE_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/include)
