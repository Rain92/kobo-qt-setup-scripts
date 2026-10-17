#!/bin/bash
set -e

USAGE="usage: build_qt.sh [config] [make] [install]
Cross compiles Qt \${QT_VERSION} for Kobo. Without arguments all three steps are run.
Requires the host Qt from build_host.sh."

source "$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )/config.sh"

do_config=false
do_make=false
do_install=false

if [ $# -eq 0 ]; then
    do_config=true
    do_make=true
    do_install=true
fi

while test $# -gt 0
do
    case "$1" in
        config) do_config=true
            ;;
        make) do_make=true
            ;;
        install) do_install=true
            ;;
        -h|--help) echo "${USAGE}"; exit 0
            ;;
        *) echo "unknown argument: $1"; echo "${USAGE}"; exit 1
            ;;
    esac
    shift
done

if [ ! -x "${HOST_PREFIX}/bin/qmake" ]; then
    echo "Host Qt not found in ${HOST_PREFIX}, run build_host.sh first."
    exit 1
fi

if [ "$do_config" = true ] ; then
    rm -rf $KOBO_BUILD_DIR
    mkdir $KOBO_BUILD_DIR
    cd $KOBO_BUILD_DIR

    # -extprefix is the staging dir on this machine, -prefix the path on the device.
    # Qt's own evdev/libinput input handlers are disabled, the kobo platform plugin has its own.
    # Qt 6 is relocatable, so the device path only matters as a default.
    ${SRC_DIR}/configure -release -verbose -nomake examples -nomake tests \
     -qt-host-path $HOST_PREFIX \
     -extprefix $KOBO_STAGING_PREFIX \
     -prefix $KOBO_DEVICE_PREFIX \
     -device ${CROSS_TC}-g++ \
     -device-option CROSS_COMPILE=${CROSS}- \
     -submodules $(join_modules $QT_MODULES_KOBO) \
     -linuxfb -no-opengl -no-feature-vulkan -no-feature-eglfs \
     -no-xcb -no-feature-xlib -no-feature-xkbcommon -no-feature-wayland \
     -no-dbus -no-glib -no-icu -no-fontconfig \
     -no-feature-libudev -no-feature-libinput -no-feature-mtdev -no-feature-tslib -no-feature-evdev \
     -no-feature-libproxy -no-feature-brotli -no-feature-mng \
     -openssl-linked \
     -qt-libjpeg -system-libpng -system-zlib -system-freetype -system-harfbuzz -system-pcre \
     -qt-libb2 -sql-sqlite -qt-sqlite \
     -- \
     -DCMAKE_TOOLCHAIN_FILE=${SCRIPT_DIR}/qt6-kobo.cmake \
     -DOPENSSL_ROOT_DIR="${SYSROOT}/usr" -DOPENSSL_USE_STATIC_LIBS=ON \
     -DFEATURE_zstd=ON
fi

cd $KOBO_BUILD_DIR

if [ "$do_make" = true ] ; then
    cmake --build . --parallel $PARALLEL_JOBS
fi

if [ "$do_install" = true ] ; then
    cmake --install .
    mkdir -p ${KOBO_STAGING_PREFIX}/lib
    cp -R ${SCRIPT_DIR}/deploy/libadditions/fonts ${KOBO_STAGING_PREFIX}/lib
fi
