# exit when any command fails
set -e

LIBDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

export CROSS_TC=${CROSS_TC:=arm-kobo-linux-gnueabihf}
export SYSROOT=${SYSROOT:=/home/${USER}/x-tools/${CROSS_TC}/${CROSS_TC}/sysroot}
export CROSS=${CROSS:=/home/${USER}/x-tools/${CROSS_TC}/bin/${CROSS_TC}}


export AR=${CROSS}-ar
export AS=${CROSS}-as
export CC=${CROSS}-gcc
export CXX=${CROSS}-g++
export LD=${CROSS}-ld
export RANLIB=${CROSS}-ranlib


CFLAGS_BASE="-O3 -march=armv7-a -mtune=cortex-a8 -mfpu=neon -mfloat-abi=hard -mthumb -pipe -D__arm__ -D__ARM_NEON__ -fPIC -fpie -pie -fno-omit-frame-pointer -funwind-tables -Wl,--no-merge-exidx-entries"

CFLAGS_OPT1="${CFLAGS_BASE} -ftree-vectorize -ffast-math -frename-registers -funroll-loops "

CFLAGS_LTO="${CFLAGS_OPT1} -fdevirtualize-at-ltrans -flto=5"

#export CFLAGS=$CFLAGS_BASE
export CFLAGS=$CFLAGS_OPT1
#export CFLAGS=$CFLAGS_LTO

get_clean_repo()
{
    cd ${LIBDIR}
    git clone $REPO $LOCALREPO || git -C $LOCALREPO pull
    cd ${LIBDIR}/${LOCALREPO}
    git reset --hard
    git clean -fdx
    if test -f ../patches/${LOCALREPO}.patch; then
        git apply ../patches/${LOCALREPO}.patch
    fi
}


export CFLAGS=$CFLAGS_OPT1

#zlib-ng
#patch: zlib configure line 314: ARCH=armv7-a
REPO=https://github.com/zlib-ng/zlib-ng
LOCALREPO=zlib-ng
get_clean_repo

./configure --prefix=${SYSROOT}/usr --zlib-compat
make -j5 && make install


export CFLAGS=$CFLAGS_LTO


#pnglib
REPO=git://git.code.sf.net/p/libpng/code
LOCALREPO=pnglib
get_clean_repo

./configure --prefix=${SYSROOT}/usr --host=${CROSS_TC} --enable-arm-neon=check
make -j5 && make install


#libjpeg-turbo
#needed: toolchain.cmake
REPO=https://github.com/libjpeg-turbo/libjpeg-turbo
LOCALREPO=libjpeg-turbo
get_clean_repo

mkdir -p ${LIBDIR}/${LOCALREPO}/build
cd ${LIBDIR}/${LOCALREPO}/build
cmake -D CMAKE_BUILD_TYPE=RELEASE -D CMAKE_INSTALL_PREFIX=${SYSROOT}/usr -DCMAKE_TOOLCHAIN_FILE=../${CROSS_TC}.cmake -DENABLE_NEON=ON -DNEON_INTRINSICS=ON ..
make -j5 && make install


#expat
REPO=https://github.com/libexpat/libexpat
LOCALREPO=expat
get_clean_repo

cd ${LIBDIR}/${LOCALREPO}/expat
./buildconf.sh
./configure --prefix=${SYSROOT}/usr --host=${CROSS_TC}
make -j5 && make install


#openssl
REPO="--single-branch --branch OpenSSL_1_1_1-stable https://github.com/openssl/openssl"
LOCALREPO=openssl-1.1.1
get_clean_repo

./Configure linux-elf no-comp no-asm shared --prefix=${SYSROOT}/usr --openssldir=${SYSROOT}/usr
make -j5 && make install_sw 


#pcre
REPO=https://github.com/rurban/pcre
LOCALREPO=pcre
get_clean_repo

./autogen.sh
./configure --prefix=${SYSROOT}/usr --host=${CROSS_TC} --enable-pcre2-16 --enable-jit --with-sysroot=${SYSROOT}
make -j5 && make install

  
#libfreetype without harfbuzz
REPO=https://github.com/freetype/freetype
LOCALREPO=freetype
get_clean_repo

sh autogen.sh
./configure --prefix=${SYSROOT}/usr --host=${CROSS_TC} --enable-shared=yes --enable-static=yes --without-bzip2 --without-harfbuzz --without-png --disable-freetype-config
make -j5 && make install


#harfbuzz
REPO=https://github.com/harfbuzz/harfbuzz
LOCALREPO=harfbuzz
get_clean_repo

sh autogen.sh --prefix=${SYSROOT}/usr --host=${CROSS_TC} --enable-shared=yes --enable-static=yes --without-coretext --without-fontconfig --without-uniscribe --without-cairo --without-glib  --without-gobject --without-graphite2 --without-icu --disable-introspection --with-freetype
#./configure --prefix=${SYSROOT}/usr --host=${CROSS_TC} --enable-shared=yes --enable-static=yes --without-coretext --without-fontconfig --without-uniscribe --without-cairo --without-glib  --without-gobject --without-graphite2 --without-icu --disable-introspection --with-freetype
make -j5 && make install

#libfreetype with harfbuzz
REPO=https://github.com/freetype/freetype
LOCALREPO=freetype
get_clean_repo

sh autogen.sh 
./configure --prefix=${SYSROOT}/usr --host=${CROSS_TC} --enable-shared=yes --enable-static=yes --without-bzip2 --with-harfbuzz --with-png --disable-freetype-config
make -j5 && make install
