#!/bin/bash
set -e #-x

USAGE="usage: build_qt.sh [kobo|desktop] [config] [make] [install]"

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

LOCALREPO_KOBO=qt-linux-5.15-kde-kobo
LOCALREPO_DESKTOP=qt-linux-5.15-kde-desktop

CROSS_TC=${CROSS_TC:=arm-kobo-linux-gnueabihf}

SYSROOT=${SYSROOT:=/home/${USER}/x-tools/${CROSS_TC}/${CROSS_TC}/sysroot}
CROSS=${CROSS:=/home/${USER}/x-tools/${CROSS_TC}/bin/${CROSS_TC}}

PREFIX_KOBO=${PREFIX:-/home/${USER}/qt-bin/${LOCALREPO_KOBO}}
PREFIX_DESKTOP=${PREFIX:-/home/${USER}/qt-bin/${LOCALREPO_DESKTOP}}

PARALLEL_JOBS=$(($(getconf _NPROCESSORS_ONLN 2> /dev/null || sysctl -n hw.ncpu 2> /dev/null || echo 0) + 1))

CONFIG_KOBO="--recheck-all -opensource -confirm-license -release -verbose \
 -prefix /mnt/onboard/.adds/${LOCALREPO_KOBO} \
 -extprefix $PREFIX_KOBO \
 -xplatform ${CROSS_TC}-g++ \
 -sysroot ${SYSROOT} \
 -openssl-linked OPENSSL_PREFIX="${SYSROOT}/usr" \
 -system-libjpeg -system-zlib -system-libpng -system-freetype -system-harfbuzz -system-pcre -sql-sqlite -linuxfb \
 -no-sse2 -no-xcb -no-xcb-xlib -no-xkbcommon -no-tslib -no-icu -no-iconv -no-dbus -no-fontconfig \
 -nomake tests -nomake examples -no-compile-examples -no-opengl \
 -no-cups -no-pch \
 -no-sql-db2 -no-sql-ibase -no-sql-mysql -no-sql-oci -no-sql-odbc -no-sql-psql -no-sql-sqlite2 -no-sql-tds \
 -no-feature-printdialog -no-feature-printer -no-feature-printpreviewdialog -no-feature-printpreviewwidget"

CONFIG_DESKTOP="--recheck-all -opensource -confirm-license -release -verbose \
 -prefix $PREFIX_DESKTOP  \
 -openssl \
 -system-libjpeg -system-zlib -system-libpng -system-freetype -system-harfbuzz -system-pcre -sql-sqlite -linuxfb \
 -no-tslib -no-icu -no-iconv -no-dbus -no-fontconfig \
 -nomake tests -nomake examples -no-compile-examples -no-opengl \
 -no-pch \
 -no-sql-db2 -no-sql-ibase -no-sql-mysql -no-sql-oci -no-sql-odbc -no-sql-psql -no-sql-sqlite2 -no-sql-tds"

do_config=false
do_make=false
do_install=false

platform=kobo
config=$CONFIG_KOBO
localrepo=$LOCALREPO_KOBO


case ${1:-kobo} in
    kobo)
        platform=kobo
        config=$CONFIG_KOBO
        localrepo=$LOCALREPO_KOBO
        PREFIX=$PREFIX_KOBO
        ;;
    desktop)
        platform=desktop
        config=$CONFIG_DESKTOP
        localrepo=$LOCALREPO_DESKTOP
        PREFIX=$PREFIX_DESKTOP
        ;;
    *)
        echo "Missing platform argument, defaulting to kobo"
        ;;
esac

while test $# -gt 0
do
    case "$1" in
        config) do_config=true
            ;;
        make) do_make=true
            ;;
        install) do_install=true
            ;;
        *)
            ;;
    esac
    shift
done

cd $localrepo


if [ "$do_config" = true ] ; then
    ./configure $config
fi

if [ "$do_make" = true ] ; then
    make -j$PARALLEL_JOBS
fi

if [ "$do_install" = true ] ; then
    make install
    cp -R ${SCRIPT_DIR}/deploy/libadditions/fonts ${PREFIX}/lib
fi
