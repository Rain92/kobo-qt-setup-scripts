#!/bin/bash
# Usage: install_libs.sh [lib ...]
# Downloads, builds and installs the Qt dependencies into the toolchain sysroot.
# Without arguments all libs are built in dependency order, otherwise only the given ones:
# zlib-ng libb2 zstd openssl libpng libjpeg-turbo expat pcre2 freetype harfbuzz
set -e

LIBDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

# path to cross tools root; another popular path is ${HOME}/x-tools
CROSS_TC_PATH=${CROSS_TC_PATH:=${HOME}/kobo/x-tools}

CROSS_TC=${CROSS_TC:=arm-kobo-linux-gnueabihf}

SYSROOT=${SYSROOT:=${CROSS_TC_PATH}/${CROSS_TC}/${CROSS_TC}/sysroot}
CROSS=${CROSS:=${CROSS_TC_PATH}/${CROSS_TC}/bin/${CROSS_TC}}
PREFIX=${PREFIX:=${SYSROOT}/usr}

PARALLEL_JOBS=$(($(getconf _NPROCESSORS_ONLN 2> /dev/null || sysctl -n hw.ncpu 2> /dev/null || echo 0) + 1))

# pinned upstream releases (git tags or branches), bump these to update
ZLIB_NG_VERSION=2.3.3
LIBB2_VERSION=master            # no release since v0.98.1 (2018)
ZSTD_VERSION=v1.5.7
OPENSSL_VERSION=openssl-3.5.9   # 3.5 is the LTS branch (supported until 04/2030)
LIBPNG_VERSION=v1.6.59
LIBJPEG_TURBO_VERSION=3.2.0
EXPAT_VERSION=R_2_9_0
PCRE2_VERSION=pcre2-10.49
FREETYPE_VERSION=VER-2-14-3
HARFBUZZ_VERSION=14.6.0

export AR=${CROSS}-ar
export AS=${CROSS}-as
export CC=${CROSS}-gcc
export CXX=${CROSS}-g++
export LD=${CROSS}-ld
export RANLIB=${CROSS}-ranlib

export PKG_CONFIG_PATH=""
export PKG_CONFIG_LIBDIR="${SYSROOT}/usr/lib/pkgconfig:${SYSROOT}/usr/share/pkgconfig"
export PKG_CONFIG="pkg-config"
# the installed .pc files contain absolute sysroot paths, a PKG_CONFIG_SYSROOT_DIR would prepend it twice
unset PKG_CONFIG_SYSROOT_DIR


CFLAGS_BASE="-O3 -march=armv7-a -mtune=cortex-a8 -mfpu=neon -mfloat-abi=hard -mthumb -pipe -D__arm__ -D__ARM_NEON__ -fPIC -fno-omit-frame-pointer -funwind-tables -Wl,--no-merge-exidx-entries"

# with -ffast-math the glibc 2.15 bits/math-finite.h uses lgamma_r undeclared in strict modes, an error since GCC 14
CFLAGS_OPT1="${CFLAGS_BASE} -ftree-vectorize -ffast-math -frename-registers -funroll-loops -Wno-error=implicit-function-declaration"

# fat LTO objects keep the static archives usable for consumers that do not use LTO (e.g. Qt)
CFLAGS_LTO="${CFLAGS_OPT1} -fdevirtualize-at-ltrans -flto=5 -ffat-lto-objects"

CMAKE_CROSS_ARGS="-DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=${PREFIX} -DCMAKE_INSTALL_LIBDIR=lib -DCMAKE_TOOLCHAIN_FILE=${LIBDIR}/${CROSS_TC}.cmake"

get_clean_repo()
{
    mkdir -p ${LIBDIR}/libs
    cd ${LIBDIR}/libs
    if [ ! -d ${LOCALREPO}/.git ]; then
        git init -q ${LOCALREPO}
        git -C ${LOCALREPO} remote add origin ${REPO}
    fi
    cd ${LIBDIR}/libs/${LOCALREPO}
    git remote set-url origin ${REPO}
    git fetch --depth 1 origin ${VERSION}
    git checkout -q -f FETCH_HEAD
    git clean -ffdxq
    if [ -n "${SUBMODULES}" ]; then
        git submodule update --init --recursive --depth 1 ${SUBMODULES}
    fi
    if test -f ${LIBDIR}/patches/${LOCALREPO}.patch; then
        git apply ${LIBDIR}/patches/${LOCALREPO}.patch
    fi
}

meson_cross_file()
{
    local file=${LIBDIR}/libs/${CROSS_TC}.meson
    local args=$(printf "'%s', " $1)
    cat > $file << EOF
[binaries]
c = '${CROSS}-gcc'
cpp = '${CROSS}-g++'
ar = '${CROSS}-gcc-ar'
nm = '${CROSS}-gcc-nm'
ranlib = '${CROSS}-gcc-ranlib'
strip = '${CROSS}-strip'
pkg-config = 'pkg-config'

[properties]
pkg_config_libdir = ['${SYSROOT}/usr/lib/pkgconfig', '${SYSROOT}/usr/share/pkgconfig']

[built-in options]
c_args = [${args}]
cpp_args = [${args}]
c_link_args = [${args}]
cpp_link_args = [${args}]

[host_machine]
system = 'linux'
cpu_family = 'arm'
cpu = 'armv7-a'
endian = 'little'
EOF
    echo $file
}


build_zlib_ng()
{
    REPO=https://github.com/zlib-ng/zlib-ng
    LOCALREPO=zlib-ng
    VERSION=$ZLIB_NG_VERSION
    get_clean_repo

    # glibc 2.15 has no getauxval, so select the NEON code at compile time instead of runtime detection
    # built without LTO
    CFLAGS=$CFLAGS_OPT1 cmake -B build ${CMAKE_CROSS_ARGS} -DCMAKE_C_FLAGS_RELEASE="-DNDEBUG" \
        -DZLIB_COMPAT=ON -DWITH_RUNTIME_CPU_DETECTION=OFF -DWITH_GTEST=OFF -DZLIB_ENABLE_TESTS=OFF -DZLIBNG_ENABLE_TESTS=OFF
    cmake --build build -j$PARALLEL_JOBS && cmake --install build
}

build_libb2()
{
    REPO=https://github.com/BLAKE2/libb2
    LOCALREPO=libb2
    VERSION=$LIBB2_VERSION
    get_clean_repo

    sh autogen.sh --prefix=${PREFIX} --host=${CROSS_TC}
    ./configure --prefix=${PREFIX} --host=${CROSS_TC} --disable-native
    make -j$PARALLEL_JOBS && make install
}

build_zstd()
{
    REPO=https://github.com/facebook/zstd
    LOCALREPO=zstd
    VERSION=$ZSTD_VERSION
    get_clean_repo

    cd build/cmake
    # glibc 2.15 needs librt for clock_gettime
    cmake -B build ${CMAKE_CROSS_ARGS} -DADDITIONAL_CXX_FLAGS="-lrt" -DZSTD_BUILD_TESTS=OFF
    cmake --build build -j$PARALLEL_JOBS && cmake --install build
}

build_openssl()
{
    REPO=https://github.com/openssl/openssl
    LOCALREPO=openssl
    VERSION=$OPENSSL_VERSION
    get_clean_repo

    # linked statically into Qt 6, so no LTO and no fast-math; linux-armv4 enables the NEON assembler code
    # linux-armv4 always adds -latomic, but gcc inlines all atomics on armv7, --as-needed drops the unused libatomic.so.1
    CFLAGS=$CFLAGS_BASE ./Configure linux-armv4 no-comp no-tests no-docs shared --prefix=${PREFIX} --openssldir=${PREFIX} --libdir=lib -Wl,--as-needed
    make -j$PARALLEL_JOBS && make install_sw
}

build_libpng()
{
    REPO=https://github.com/pnggroup/libpng
    LOCALREPO=libpng
    VERSION=$LIBPNG_VERSION
    get_clean_repo

    [ -x configure ] || ./autogen.sh
    ./configure --prefix=${PREFIX} --host=${CROSS_TC} --enable-arm-neon=yes
    make -j$PARALLEL_JOBS && make install
}

build_libjpeg_turbo()
{
    REPO=https://github.com/libjpeg-turbo/libjpeg-turbo
    LOCALREPO=libjpeg-turbo
    VERSION=$LIBJPEG_TURBO_VERSION
    get_clean_repo

    cmake -B build ${CMAKE_CROSS_ARGS} -DWITH_SIMD=ON -DNEON_INTRINSICS=ON
    cmake --build build -j$PARALLEL_JOBS && cmake --install build
}

build_expat()
{
    REPO=https://github.com/libexpat/libexpat
    LOCALREPO=expat
    VERSION=$EXPAT_VERSION
    get_clean_repo

    cd expat
    ./buildconf.sh
    # no getrandom (kernel < 3.17, glibc 2.15) and no arc4random on Kobo, use /dev/urandom as entropy source
    ./configure --prefix=${PREFIX} --host=${CROSS_TC} --without-docbook --without-examples --without-tests CPPFLAGS=-DXML_DEV_URANDOM
    make -j$PARALLEL_JOBS && make install
}

build_pcre2()
{
    REPO=https://github.com/PCRE2Project/pcre2
    LOCALREPO=pcre2
    VERSION=$PCRE2_VERSION
    SUBMODULES=deps/sljit
    get_clean_repo

    ./autogen.sh
    ./configure --prefix=${PREFIX} --host=${CROSS_TC} --enable-pcre2-16 --enable-jit --with-sysroot=${SYSROOT}
    make -j$PARALLEL_JOBS && make install
}

# $1: with or without harfbuzz, freetype and harfbuzz depend on each other
build_freetype()
{
    REPO=https://github.com/freetype/freetype
    LOCALREPO=freetype
    VERSION=$FREETYPE_VERSION
    SUBMODULES=subprojects/dlg
    get_clean_repo

    sh autogen.sh
    ./configure --prefix=${PREFIX} --host=${CROSS_TC} --enable-shared=yes --enable-static=yes --without-bzip2 --without-brotli --$1-harfbuzz --with-png --disable-freetype-config
    make -j$PARALLEL_JOBS && make install
}

build_harfbuzz()
{
    REPO=https://github.com/harfbuzz/harfbuzz
    LOCALREPO=harfbuzz
    VERSION=$HARFBUZZ_VERSION
    get_clean_repo

    # leftovers of the old autotools build would make libtool link freetype against the old version
    rm -f ${PREFIX}/lib/libharfbuzz*.la

    # meson takes compilers and flags from the cross file only
    env -u CC -u CXX -u AR -u AS -u LD -u RANLIB -u CFLAGS -u CXXFLAGS -u LDFLAGS \
    meson setup build --cross-file $(meson_cross_file "$CFLAGS_LTO") --prefix=${PREFIX} --libdir=lib \
        --buildtype=release -Db_ndebug=true -Ddefault_library=both \
        -Dfreetype=enabled -Dglib=disabled -Dgobject=disabled -Dcairo=disabled -Dchafa=disabled \
        -Dicu=disabled -Dgraphite2=disabled -Dpng=disabled -Dzlib=disabled \
        -Draster=disabled -Dvector=disabled -Dgpu=disabled -Dgpu_demo=disabled \
        -Dtests=disabled -Dintrospection=disabled -Ddocs=disabled -Dutilities=disabled
    meson compile -C build -j $PARALLEL_JOBS && meson install -C build
}


LIBS="$@"
if [ -z "$LIBS" ]; then
    LIBS="zlib-ng libb2 zstd openssl libpng libjpeg-turbo expat pcre2 freetype-bootstrap harfbuzz freetype"
fi

for lib in $LIBS; do
    export CFLAGS=$CFLAGS_LTO
    SUBMODULES=
    case $lib in
        zlib-ng)            build_zlib_ng ;;
        libb2)              build_libb2 ;;
        zstd)               build_zstd ;;
        openssl)            build_openssl ;;
        libpng)             build_libpng ;;
        libjpeg-turbo)      build_libjpeg_turbo ;;
        expat)              build_expat ;;
        pcre2)              build_pcre2 ;;
        freetype-bootstrap) build_freetype without ;;
        freetype)           build_freetype with ;;
        harfbuzz)           build_harfbuzz ;;
        *) echo "unknown lib: $lib"; exit 1 ;;
    esac
done
