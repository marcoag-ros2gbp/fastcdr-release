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

# get_set_stdcxx() checks and sets the compiler standard level
#   stdversion: the level of standard fullfilment
#   stdfeature: the feature name associated with that level
#   gcc_flag:   the gcc/clang flag for fallback
#   cl_flag:    the cl flag for fallback
#   force:      if the user should enforced this standard level or not (FORCE_CXX)
#   result:     a return variable to check if this level is available

function(get_set_stdcxx stdversion stdfeature gcc_flag cl_flag force result)

    set(${result} 0 PARENT_SCOPE)

    # check if CMake feature management is available
    get_property(CXX_KNOWN_FEATURES GLOBAL PROPERTY CMAKE_CXX_KNOWN_FEATURES)
    if((stdfeature IN_LIST CXX_KNOWN_FEATURES) AND NOT ("run_fallback_test" IN_LIST ARGV))
        # CMake is aware let's check if is available
        if(force AND (stdfeature IN_LIST CMAKE_CXX_COMPILE_FEATURES))
            # is available report and enforce as commanded
            # avoid using CACHE variables to avoid polute projects that use this repo as subdir
            set(CMAKE_CXX_STANDARD ${stdversion} PARENT_SCOPE)
            set(${result} 1 PARENT_SCOPE)
            message(STATUS "Enforced ${stdfeature} CMake feature")
        elseif(force)
            message(FATAL_ERROR "The specified C++ ${stdfeature} feature is not supported using default compiler.")
        endif()
    else()
        # fallback to the old behaviour
        include(CheckCXXCompilerFlag)

        if(gcc_flag AND (
           CMAKE_COMPILER_IS_GNUCXX OR CMAKE_COMPILER_IS_CLANG OR
           CMAKE_CXX_COMPILER_ID MATCHES "Clang" OR
           CMAKE_CXX_COMPILER_ID MATCHES "QCC"))
            # check using gcc/clang flags
            check_cxx_compiler_flag(${gcc_flag} SUPPORTS_${stdfeature})
            if(SUPPORTS_${stdfeature} AND force)
                add_compile_options($<$<COMPILE_LANGUAGE:CXX>:${gcc_flag}>)
                set(${result} 1 PARENT_SCOPE)
                message(STATUS "Enforced ${gcc_flag} CMake feature")
            elseif((NOT SUPPORTS_${stdfeature}) AND force)
                message(FATAL_ERROR "Force to support ${stdfeature} but not supported by gnu compiler")
            endif()
        elseif(cl_flag AND (MSVC OR MSVC_IDE))
            # check using cl flags
            check_cxx_compiler_flag(${cl_flag} SUPPORTS_${stdfeature})
            if(SUPPORTS_${stdfeature} AND force)
                add_compile_options($<$<COMPILE_LANGUAGE:CXX>:${cl_flag}>)
                set(${result} 1 PARENT_SCOPE)
                message(STATUS "Enforced ${cl_flag} CMake feature")
            elseif((NOT SUPPORTS_${stdfeature}) AND force)
                message(FATAL_ERROR "Force to support ${stdfeature} but not supported by MSVC")
            endif()
       elseif(force)
           message(WARNING "The specified C++ ${stdfeature} feature is not supported using default compiler.")
       endif()

    endif()

endfunction()

function(check_stdcxx enforced_level)

    # Map force values to cmake features
    set(cxx_levels 23 20 17 14 1Y 11)
    set(cxx_features cxx_std_23 cxx_std_20 cxx_std_17 cxx_std_14 NOTFOUND cxx_std_11)
    set(gcc_flags -std=c++23 -std=c++20 -std=c++17 -std=c++14 -std=c++1y -std=c++11)
    set(cl_flags /std:c++23 /std:c++20 /std:c++17 /std:c++14 NOTFOUND NOTFOUND)
    set(HAVE_CXX HAVE_CXX23 HAVE_CXX20 HAVE_CXX17 HAVE_CXX14 HAVE_CXX1Y HAVE_CXX11)

    # Traverse the collection
    while(cxx_levels)

        # pop current values
        list(POP_FRONT cxx_levels level)
        list(POP_FRONT cxx_features feature)
        list(POP_FRONT gcc_flags gcc_flag)
        list(POP_FRONT cl_flags cl_flag)
        list(POP_FRONT HAVE_CXX preprocessor_flag)

        # check if we must enforce this one
        if(enforced_level STREQUAL level)
            set(force TRUE)
        else()
            set(force FALSE)
        endif()

        # testing framework awareness
        set(test)
        if("run_fallback_test" IN_LIST ARGV)
            set(test "run_fallback_test")
        endif()

        # check
        get_set_stdcxx(${level} ${feature} ${gcc_flag} ${cl_flag} ${force} result ${test})

        if(result)
            # we are done, mark all levels below as available 
            set(${preprocessor_flag} 1 PARENT_SCOPE)
            # upload local variable fixed by get_set_stdcxx
            set(CMAKE_CXX_STANDARD ${CMAKE_CXX_STANDARD} PARENT_SCOPE)
            while(HAVE_CXX)
                list(POP_FRONT HAVE_CXX preprocessor_flag)
                set(${preprocessor_flag} 1 PARENT_SCOPE)
            endwhile()
            break()
        else()
            # If the user doesn't enforce this level the macros are not trustworthy
            set(${preprocessor_flag} 0 PARENT_SCOPE)
        endif()    

    endwhile()    

endfunction()

macro(check_type_sizes)
    include(CheckTypeSize)
    check_type_size("long double" TYPE_LONG_DOUBLE LANGUAGE CXX)
    set(FASTCDR_SIZEOF_LONG_DOUBLE ${TYPE_LONG_DOUBLE})
    check_type_size("__float128" TYPE_FLOAT128 LANGUAGE CXX)
    if(HAVE_TYPE_FLOAT128)
        set(FASTCDR_HAVE_FLOAT128 1)
    else()
        set(FASTCDR_HAVE_FLOAT128 0)
    endif()
endmacro()

macro(check_endianness)
    if(CMAKE_CXX_BYTE_ORDER)
        if(CMAKE_CXX_BYTE_ORDER STREQUAL "BIG_ENDIAN")
            set(FASTCDR_IS_BIG_ENDIAN_TARGET 1)
        else()
            set(FASTCDR_IS_BIG_ENDIAN_TARGET 0)
        endif()
    else()
        # Test endianness
        include(TestBigEndian)
        test_big_endian(BIG_ENDIAN)
        set(FASTCDR_IS_BIG_ENDIAN_TARGET ${BIG_ENDIAN})
    endif()
endmacro()

macro(check_msvc_arch)
    if(MSVC_VERSION EQUAL 1700)
        if(CMAKE_CL_64)
            set(MSVC_ARCH "x64Win64VS2012")
        else()
            set(MSVC_ARCH "i86Win32VS2012")
        endif()
    elseif(MSVC_VERSION EQUAL 1800)
        if(CMAKE_CL_64)
            set(MSVC_ARCH "x64Win64VS2013")
        else()
            set(MSVC_ARCH "i86Win32VS2013")
        endif()
    elseif(MSVC_VERSION EQUAL 1900)
        if(CMAKE_CL_64)
            set(MSVC_ARCH "x64Win64VS2015")
        else()
            set(MSVC_ARCH "i86Win32VS2015")
        endif()
    elseif(MSVC_VERSION GREATER 1900)
        if(CMAKE_CL_64)
            set(MSVC_ARCH "x64Win64VS2017")
        else()
            set(MSVC_ARCH "i86Win32VS2017")
        endif()
    else()
        if(CMAKE_CL_64)
            set(MSVC_ARCH "x64Win64VSUnknown")
        else()
            set(MSVC_ARCH "i86Win32VSUnknown")
        endif()
    endif()
endmacro()

function(set_common_compile_options target)
    enable_language(C)
    enable_language(CXX)
    if(MSVC OR MSVC_IDE)
        target_compile_options(${target} PRIVATE /W4)
    else()
        target_compile_options(${target} PRIVATE -Wall
            -Wextra
            -Wshadow
            $<$<COMPILE_LANGUAGE:CXX>:-Wnon-virtual-dtor>
            -pedantic
            -Wcast-align
            -Wunused
            $<$<COMPILE_LANGUAGE:CXX>:-Woverloaded-virtual>
            -Wconversion
            -Wsign-conversion
            $<$<CXX_COMPILER_ID:GNU>:-Wlogical-op>
            $<$<AND:$<CXX_COMPILER_ID:GNU>,$<COMPILE_LANGUAGE:CXX>>:-Wuseless-cast>
            -Wdouble-promotion
            $<$<COMPILE_LANGUAGE:CXX>:-Wold-style-cast>
            $<$<OR:$<AND:$<CXX_COMPILER_ID:GNU>,$<NOT:$<VERSION_LESS:$<CXX_COMPILER_VERSION>,6.0.0>>>,$<AND:$<C_COMPILER_ID:GNU>,$<NOT:$<VERSION_LESS:$<C_COMPILER_VERSION>,6.0.0>>>>:-Wnull-dereference>
            $<$<OR:$<AND:$<CXX_COMPILER_ID:GNU>,$<NOT:$<VERSION_LESS:$<CXX_COMPILER_VERSION>,7.0.0>>>,$<AND:$<C_COMPILER_ID:GNU>,$<NOT:$<VERSION_LESS:$<C_COMPILER_VERSION>,7.0.0>>>>:-Wduplicated-branches>
            $<$<OR:$<AND:$<CXX_COMPILER_ID:GNU>,$<NOT:$<VERSION_LESS:$<CXX_COMPILER_VERSION>,6.0.0>>>,$<AND:$<C_COMPILER_ID:GNU>,$<NOT:$<VERSION_LESS:$<C_COMPILER_VERSION>,6.0.0>>>>:-Wduplicated-cond>
            $<$<OR:$<AND:$<CXX_COMPILER_ID:GNU>,$<NOT:$<VERSION_LESS:$<CXX_COMPILER_VERSION>,7.0.0>>>,$<AND:$<C_COMPILER_ID:GNU>,$<NOT:$<VERSION_LESS:$<C_COMPILER_VERSION>,7.0.0>>>>:-Wrestrict>
            )
    endif()
endfunction()
