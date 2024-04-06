cmake_minimum_required(VERSION 3.18)
include_guard(GLOBAL)

SET(CMAKE_SYSTEM_NAME Linux)

set(CMAKE_SYSTEM_PROCESSOR arm)

set(GCC_COMPILER_VERSION "" CACHE STRING "GCC Compiler version")
set(GNU_MACHINE "arm-kobo-linux-gnueabihf" CACHE STRING "GNU compiler triple")
set(ENABLE_NEON TRUE)

set(TARGET_SYSROOT /home/$ENV{USER}/x-tools/arm-kobo-linux-gnueabihf/arm-kobo-linux-gnueabihf/sysroot/)
set(CROSS_COMPILER /home/$ENV{USER}/x-tools/arm-kobo-linux-gnueabihf/bin/arm-kobo-linux-gnueabihf)

set(CMAKE_SYSROOT ${TARGET_SYSROOT})
set(ARM_LINUX_SYSROOT ${TARGET_SYSROOT})
set(CMAKE_FIND_ROOT_PATH ${TARGET_SYSROOT})


set(ENV{PKG_CONFIG_PATH} "")
set(ENV{PKG_CONFIG_LIBDIR} ${CMAKE_SYSROOT}/usr/lib/pkgconfig:${CMAKE_SYSROOT}/usr/share/pkgconfig)
set(ENV{PKG_CONFIG_SYSROOT_DIR} ${CMAKE_SYSROOT})


set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_PACKAGE ONLY)


set(LOCAL_ARM_NEON TRUE)
set(ARCH_ARM_HAVE_NEON TRUE)

set(FLOAT_ABI_SUFFIX "hf")  


set(CMAKE_C_COMPILER ${CROSS_COMPILER}-gcc)
set(CMAKE_CXX_COMPILER ${CROSS_COMPILER}-g++)
set(CMAKE_AR ${CROSS_COMPILER}-ar)


set(QT_COMPILER_FLAGS "-march=armv7-a -mtune=cortex-a8 -mfpu=neon -mfloat-abi=hard -mthumb -D__arm__ -D__ARM_NEON__ -fPIC -fpie -pie -fno-omit-frame-pointer -funwind-tables ${ADDITIONAL_CXX_FLAGS} ")
set(QT_COMPILER_FLAGS_RELEASE "-O3 -pipe -ftree-vectorize -ffast-math -frename-registers -funroll-loops -fdevirtualize-at-ltrans -flto=5")
set(QT_LINKER_FLAGS "-Wl,-O1 -Wl,--hash-style=gnu -Wl,--as-needed -Wl,--no-merge-exidx-entries")

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
