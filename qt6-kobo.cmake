cmake_minimum_required(VERSION 3.18)
include_guard(GLOBAL)

set(CMAKE_SYSTEM_NAME Linux)
set(CMAKE_SYSTEM_PROCESSOR arm)

set(CROSS_TC arm-kobo-linux-gnueabihf)

# Can be overridden from the environment, defaults match install_toolchain.sh
if(DEFINED ENV{KOBO_XTOOLS})
    set(KOBO_XTOOLS $ENV{KOBO_XTOOLS})
else()
    set(KOBO_XTOOLS $ENV{HOME}/kobo/x-tools)
endif()

set(CROSS ${KOBO_XTOOLS}/${CROSS_TC}/bin)
set(TARGET_SYSROOT ${KOBO_XTOOLS}/${CROSS_TC}/${CROSS_TC}/sysroot)
set(CMAKE_SYSROOT ${TARGET_SYSROOT})

# pkg-config only looks at the environment, so these have to be ENV{} and not plain cmake variables.
# No PKG_CONFIG_SYSROOT_DIR: install_libs.sh installs with prefix=${SYSROOT}/usr, so the .pc files
# already contain absolute paths into the sysroot.
set(ENV{PKG_CONFIG_PATH} "")
set(ENV{PKG_CONFIG_LIBDIR} ${TARGET_SYSROOT}/usr/lib/pkgconfig:${TARGET_SYSROOT}/usr/share/pkgconfig)

set(CMAKE_C_COMPILER ${CROSS}/${CROSS_TC}-gcc)
set(CMAKE_CXX_COMPILER ${CROSS}/${CROSS_TC}-g++)
set(CMAKE_AR ${CROSS}/${CROSS_TC}-ar CACHE FILEPATH "")
set(CMAKE_RANLIB ${CROSS}/${CROSS_TC}-ranlib CACHE FILEPATH "")
set(CMAKE_STRIP ${CROSS}/${CROSS_TC}-strip CACHE FILEPATH "")

set(QT_COMPILER_FLAGS "-march=armv7-a -mtune=cortex-a8 -mfpu=neon -mfloat-abi=hard -mthumb -D__arm__ -D__ARM_NEON__ -fPIC -fno-omit-frame-pointer -funwind-tables")
set(QT_COMPILER_FLAGS_RELEASE "-O3 -pipe")
set(QT_LINKER_FLAGS "-Wl,-O1 -Wl,--hash-style=gnu -Wl,--as-needed -Wl,--no-merge-exidx-entries")

set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_PACKAGE ONLY)

include(CMakeInitializeConfigs)

function(cmake_initialize_per_config_variable _PREFIX _DOCSTRING)
  if (_PREFIX MATCHES "CMAKE_(C|CXX|ASM)_FLAGS")
    set(CMAKE_${CMAKE_MATCH_1}_FLAGS_INIT "${QT_COMPILER_FLAGS}")

    foreach (config DEBUG RELEASE MINSIZEREL RELWITHDEBINFO)
      if (DEFINED QT_COMPILER_FLAGS_${config})
        set(CMAKE_${CMAKE_MATCH_1}_FLAGS_${config}_INIT "${QT_COMPILER_FLAGS_${config}}")
      endif()
    endforeach()
  endif()


  if (_PREFIX MATCHES "CMAKE_(SHARED|MODULE|EXE)_LINKER_FLAGS")
    foreach (config SHARED MODULE EXE)
      set(CMAKE_${config}_LINKER_FLAGS_INIT "${QT_LINKER_FLAGS}")
    endforeach()
  endif()

  _cmake_initialize_per_config_variable(${ARGV})
endfunction()
