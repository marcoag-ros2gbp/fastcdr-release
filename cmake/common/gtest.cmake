# Copyright 2016 Proyectos y Sistemas de Mantenimiento SL (eProsima).
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

option(GTEST_INDIVIDUAL "Activate the execution of GTest tests" OFF)

macro(check_gtest)
    if(NOT GTEST_FOUND)
        if(WIN32)
            option(EPROSIMA_GTEST "Activate special set of GTEST_ROOT" OFF)
            if(EPROSIMA_BUILD)
                set(EPROSIMA_GTEST ON)
            endif()
        endif()

        # Find package GTest
        if(WIN32 AND EPROSIMA_GTEST)
            if(NOT GTEST_ROOT)
                set(GTEST_ROOT_ $ENV{GTEST_ROOT})
                if(GTEST_ROOT_)
                    file(TO_CMAKE_PATH "${GTEST_ROOT_}/${MSVC_ARCH}" GTEST_ROOT)
                endif()
            else()
                file(TO_CMAKE_PATH "${GTEST_ROOT}/${MSVC_ARCH}" GTEST_ROOT)
            endif()
        endif()
        find_package(GTest)

        if(GTEST_FOUND)
            find_package(Threads REQUIRED)
            set(GTEST_LIBRARIES ${GTEST_LIBRARIES} ${CMAKE_THREAD_LIBS_INIT})
            set(GTEST_BOTH_LIBRARIES ${GTEST_BOTH_LIBRARIES} ${CMAKE_THREAD_LIBS_INIT})
        endif()
    endif()
endmacro()

macro(check_gmock)
    if(NOT GMOCK_FOUND)
        if(WIN32)
            option(EPROSIMA_GMOCK "Activate special set of GMOCK_ROOT" OFF)
            if(EPROSIMA_BUILD)
                set(EPROSIMA_GMOCK ON)
            endif()
        endif()

        # Find package GMock
        if(WIN32 AND EPROSIMA_GMOCK)
            if(NOT GMOCK_ROOT)
                set(GMOCK_ROOT_ $ENV{GMOCK_ROOT})
                if(GMOCK_ROOT_)
                    file(TO_CMAKE_PATH "${GMOCK_ROOT_}/${MSVC_ARCH}" GMOCK_ROOT)
                endif()
            else()
                file(TO_CMAKE_PATH "${GMOCK_ROOT}/${MSVC_ARCH}" GMOCK_ROOT)
            endif()
        endif()
        find_package(GMock)

        if(GMOCK_FOUND)
            find_package(Threads REQUIRED)
            set(GMOCK_LIBRARIES ${GMOCK_LIBRARIES} ${CMAKE_THREAD_LIBS_INIT})
            set(GMOCK_BOTH_LIBRARIES ${GMOCK_BOTH_LIBRARIES} ${CMAKE_THREAD_LIBS_INIT})
        endif()
    endif()
endmacro()

macro(add_gtest test)
    # Parse arguments
    set(multiValueArgs SOURCES ENVIRONMENTS DEPENDENCIES)
    cmake_parse_arguments(GTEST "" "" "${multiValueArgs}" ${ARGN})

    if(GTEST_INDIVIDUAL)
        foreach(GTEST_SOURCE_FILE ${GTEST_SOURCES})
            file(STRINGS ${GTEST_SOURCE_FILE} GTEST_NAMES REGEX ^TEST)
            foreach(GTEST_NAME ${GTEST_NAMES})
                string(REGEX REPLACE ["\) \(,"] ";" GTEST_NAME ${GTEST_NAME})
                list(GET GTEST_NAME 1 GTEST_GROUP_NAME)
                list(GET GTEST_NAME 3 GTEST_NAME)
                add_test(NAME ${GTEST_GROUP_NAME}.${GTEST_NAME}
                    COMMAND ${test}
                    --gtest_filter=${GTEST_GROUP_NAME}.${GTEST_NAME})

                # Add environment
                if(WIN32)
                    set(WIN_PATH "$ENV{PATH}")
                    get_target_property(LINK_LIBRARIES_ ${test} LINK_LIBRARIES)
                    if(NOT "${LINK_LIBRARIES_}" STREQUAL "LINK_LIBRARIES_-NOTFOUND")
                        foreach(LIBRARY_LINKED ${LINK_LIBRARIES_})
                            if(TARGET ${LIBRARY_LINKED})
                                set(WIN_PATH "$<TARGET_FILE_DIR:${LIBRARY_LINKED}>;${WIN_PATH}")
                            endif()
                        endforeach()
                    endif()
                    string(REPLACE ";" "\\;" WIN_PATH "${WIN_PATH}")
                    set_tests_properties(${test} PROPERTIES ENVIRONMENT "PATH=${WIN_PATH}")
                endif()

                foreach(property ${GTEST_ENVIRONMENTS})
                    set_property(TEST ${GTEST_GROUP_NAME}.${GTEST_NAME} APPEND PROPERTY ENVIRONMENT "${property}")
                endforeach()
            endforeach()
        endforeach()
    else()
        add_test(NAME ${test} COMMAND ${test})

        # Add environment
        if(WIN32)
            set(WIN_PATH "$ENV{PATH}")
            get_target_property(LINK_LIBRARIES_ ${test} LINK_LIBRARIES)
            if(NOT "${LINK_LIBRARIES_}" STREQUAL "LINK_LIBRARIES_-NOTFOUND")
                foreach(LIBRARY_LINKED ${LINK_LIBRARIES_})
                    if(TARGET ${LIBRARY_LINKED})
                        set(WIN_PATH "$<TARGET_FILE_DIR:${LIBRARY_LINKED}>;${WIN_PATH}")
                    endif()
                endforeach()
            endif()
            string(REPLACE ";" "\\;" WIN_PATH "${WIN_PATH}")
            set_tests_properties(${test} PROPERTIES ENVIRONMENT "PATH=${WIN_PATH}")
        endif()

        foreach(property ${GTEST_ENVIRONMENTS})
            set_property(TEST ${test} APPEND PROPERTY ENVIRONMENT "${property}")
        endforeach()
    endif()
endmacro()
