#!/bin/bash
set -e

LIBDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

CROSS_TC=${CROSS_TC:=arm-kobo-linux-gnueabihf}

SYSROOT=${SYSROOT:=/home/${USER}/kobo/x-tools/${CROSS_TC}/${CROSS_TC}/sysroot}
CROSS=${CROSS:=/home/${USER}/kobo/x-tools/${CROSS_TC}/bin/${CROSS_TC}}
PREFIX=${PREFIX:=${SYSROOT}/usr}

PARALLEL_JOBS=$(($(getconf _NPROCESSORS_ONLN 2> /dev/null || sysctl -n hw.ncpu 2> /dev/null || echo 0) + 1))

export AR=${CROSS}-ar
export AS=${CROSS}-as
export CC=${CROSS}-gcc
export CXX=${CROSS}-g++
export LD=${CROSS}-ld
export RANLIB=${CROSS}-ranlib


CFLAGS_BASE="-O3 -march=armv7-a -mtune=cortex-a8 -mfpu=neon -mfloat-abi=hard -mthumb -pipe -D__arm__ -D__ARM_NEON__ -fPIC -fpie -pie -fno-omit-frame-pointer -funwind-tables -Wl,--no-merge-exidx-entries"

CFLAGS_OPT1="${CFLAGS_BASE} -ftree-vectorize -ffast-math -frename-registers -funroll-loops "

CFLAGS_LTO="${CFLAGS_OPT1} -fdevirtualize-at-ltrans -flto=5"

get_clean_repo()
{
    mkdir -p ${LIBDIR}/libs
    cd ${LIBDIR}/libs
    git clone $REPO $LOCALREPO || git -C $LOCALREPO pull
    cd ${LIBDIR}/libs/${LOCALREPO}
    git reset --hard
    git clean -fdx
    if test -f ${LIBDIR}/patches/${LOCALREPO}.patch; then
        git apply ${LIBDIR}/patches/${LOCALREPO}.patch
    fi
}

export CFLAGS=$CFLAGS_LTO


# build zlib-ng without LTO
export CFLAGS=$CFLAGS_OPT1

#zlib-ng
#patch: zlib configure line 314: ARCH=armv7-a
REPO=https://github.com/zlib-ng/zlib-ng
LOCALREPO=zlib-ng
get_clean_repo

./configure --prefix=${PREFIX} --zlib-compat
make -j$PARALLEL_JOBS && make install


export CFLAGS=$CFLAGS_LTO


#openssl
#REPO="--single-branch --branch OpenSSL_1_1_1-stable https://github.com/openssl/openssl"
#LOCALREPO=openssl-1.1.1
REPO="--single-branch --branch openssl-3.0 https://github.com/openssl/openssl"
LOCALREPO=openssl-3.0
get_clean_repo

./Configure linux-elf no-comp no-tests no-asm shared --prefix=${PREFIX} --openssldir=${PREFIX}
make -j$PARALLEL_JOBS && make install_sw


#pnglib
REPO=git://git.code.sf.net/p/libpng/code
LOCALREPO=pnglib
get_clean_repo

./configure --prefix=${PREFIX} --host=${CROSS_TC} --enable-arm-neon=check
make -j$PARALLEL_JOBS && make install


#libjpeg-turbo
#needed: toolchain.cmake
REPO=https://github.com/libjpeg-turbo/libjpeg-turbo
LOCALREPO=libjpeg-turbo
get_clean_repo

mkdir -p ${LIBDIR}/libs/${LOCALREPO}/build
cd ${LIBDIR}/libs/${LOCALREPO}/build
cmake -D CMAKE_BUILD_TYPE=RELEASE -D CMAKE_INSTALL_PREFIX=${PREFIX} -DCMAKE_TOOLCHAIN_FILE= ${LIBDIR}/${CROSS_TC}.cmake -DENABLE_NEON=ON -DNEON_INTRINSICS=ON ..
make -j$PARALLEL_JOBS && make install

#expat
REPO=https://github.com/libexpat/libexpat
LOCALREPO=expat
get_clean_repo

cd ${LIBDIR}/libs/${LOCALREPO}/expat
./buildconf.sh
./configure --prefix=${PREFIX} --host=${CROSS_TC}
make -j$PARALLEL_JOBS && make install

#pcre
REPO=https://github.com/rurban/pcre
LOCALREPO=pcre
get_clean_repo

./autogen.sh
./configure --prefix=${PREFIX} --host=${CROSS_TC} --enable-pcre2-16 --enable-jit --with-sysroot=${SYSROOT}
make -j$PARALLEL_JOBS && make install


#libfreetype without harfbuzz
REPO=https://github.com/freetype/freetype
LOCALREPO=freetype
get_clean_repo

sh autogen.sh
./configure --prefix=${PREFIX} --host=${CROSS_TC} --enable-shared=yes --enable-static=yes --without-bzip2 --without-brotli --without-harfbuzz --without-png --disable-freetype-config
make -j$PARALLEL_JOBS && make install


#harfbuzz
REPO=https://github.com/harfbuzz/harfbuzz
LOCALREPO=harfbuzz
get_clean_repo

sh autogen.sh --prefix=${PREFIX} --host=${CROSS_TC} --enable-shared=yes --enable-static=yes --without-coretext --without-fontconfig --without-uniscribe --without-cairo --without-glib  --without-gobject --without-graphite2 --without-icu --disable-introspection --with-freetype
#./configure --prefix=${PREFIX} --host=${CROSS_TC} --enable-shared=yes --enable-static=yes --without-coretext --without-fontconfig --without-uniscribe --without-cairo --without-glib  --without-gobject --without-graphite2 --without-icu --disable-introspection --with-freetype
make -j$PARALLEL_JOBS && make install

#libfreetype with harfbuzz
REPO=https://github.com/freetype/freetype
LOCALREPO=freetype
get_clean_repo

sh autogen.sh 
./configure --prefix=${PREFIX} --host=${CROSS_TC} --enable-shared=yes --enable-static=yes --without-bzip2 --without-brotli --with-harfbuzz --with-png --disable-freetype-config
make -j$PARALLEL_JOBS && make install
