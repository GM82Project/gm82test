cmake_minimum_required(VERSION 3.19)
project(gm82test C)

set(CMAKE_MSVC_RUNTIME_LIBRARY "MultiThreaded$<$<CONFIG:Debug>:Debug>")

if(${CMAKE_C_COMPILER_ID} STREQUAL "MSVC")
	set(CMAKE_C_FLAGS "/O2 /GS- /W2 /WX")
else()
	set(CMAKE_C_FLAGS "-static-libgcc")
endif()

set(CMAKE_SHARED_LIBRARY_PREFIX "")

add_library(gm82test SHARED inst_meta.c)

option(INSTALL_GEX "Install the generated .gex" OFF)

find_package(Python COMPONENTS Interpreter)

set(GEX_URL https://raw.githubusercontent.com/GM82Project/gm82gex/main/gm82gex.py)
set(GEX_PY ${CMAKE_SOURCE_DIR}/gm82gex.py)
file(DOWNLOAD ${GEX_URL} STATUS DOWNLOAD_STATUS)
list(GET DOWNLOAD_STATUS 0 STATUS_CODE)
if(${STATUS_CODE} EQUAL 0)
	file(DOWNLOAD ${GEX_URL} ${GEX_PY})
else()
	message(WARNING "Couldn't redownload gm82gex.py")
endif()

if (INSTALL_GEX)
	add_custom_command(
		TARGET gm82test
		POST_BUILD
		COMMAND ${Python_EXECUTABLE} ${GEX_PY} gm82test.gej
		WORKING_DIRECTORY ${CMAKE_SOURCE_DIR}
		COMMENT "Building .gex"
	)
    add_custom_command(
		TARGET gm82test
		POST_BUILD
		COMMAND ${Python_EXECUTABLE} ${GEX_PY} gm82test_stub.gej
		WORKING_DIRECTORY ${CMAKE_SOURCE_DIR}
		COMMENT "Building .gex"
	)
else()
	add_custom_command(
		TARGET gm82test
		POST_BUILD
		COMMAND ${Python_EXECUTABLE} ${GEX_PY} gm82test.gej --noinstall
		WORKING_DIRECTORY ${CMAKE_SOURCE_DIR}
		COMMENT "Building .gex"
	)
	add_custom_command(
		TARGET gm82test
		POST_BUILD
		COMMAND ${Python_EXECUTABLE} ${GEX_PY} gm82test_stub.gej --noinstall
		WORKING_DIRECTORY ${CMAKE_SOURCE_DIR}
		COMMENT "Building .gex"
	)
endif()
