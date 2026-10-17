#!/bin/bash
# Shared settings for the Qt 6 scripts. Everything can be overridden from the environment,
# e.g. QT_VERSION=6.12.1 ./get_qt.sh

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

QT_VERSION=${QT_VERSION:=6.12.0}
QT_REPO=${QT_REPO:=https://github.com/qt/qt5.git}

# Modules built for the Kobo. Dependencies (e.g. qtshadertools for qtdeclarative) must be listed too.
QT_MODULES_KOBO=${QT_MODULES_KOBO:="qtbase qtshadertools qtdeclarative qtsvg qtimageformats qtwebsockets qtnetworkauth qtcharts qt5compat qtvirtualkeyboard qttools qttranslations"}
# Host build only needs to provide the build tools (moc, rcc, uic, qsb, qmlcachegen, lrelease, ...)
QT_MODULES_HOST=${QT_MODULES_HOST:="qtbase qtshadertools qtdeclarative qtsvg qttools"}

SRC_DIR="${SCRIPT_DIR}/qt-${QT_VERSION}-src"
HOST_BUILD_DIR="${SCRIPT_DIR}/qt-${QT_VERSION}-host-build"
KOBO_BUILD_DIR="${SCRIPT_DIR}/qt-${QT_VERSION}-kobo-build"

QT_BIN_ROOT=${QT_BIN_ROOT:=/home/${USER}/kobo/qt-bin}
HOST_PREFIX="${QT_BIN_ROOT}/qt-${QT_VERSION}-host"
# Staging dir on the build machine, and the location the libs are deployed to on the device
KOBO_STAGING_PREFIX="${QT_BIN_ROOT}/qt-${QT_VERSION}-kobo"
KOBO_DEVICE_PREFIX=${KOBO_DEVICE_PREFIX:=/mnt/onboard/.adds/qt-${QT_VERSION}-kobo}

CROSS_TC=${CROSS_TC:=arm-kobo-linux-gnueabihf}
export KOBO_XTOOLS=${KOBO_XTOOLS:=/home/${USER}/kobo/x-tools}
SYSROOT=${SYSROOT:=${KOBO_XTOOLS}/${CROSS_TC}/${CROSS_TC}/sysroot}
CROSS=${CROSS:=${KOBO_XTOOLS}/${CROSS_TC}/bin/${CROSS_TC}}

# Qt translation units can need >1GB of RAM each, so don't blindly use every core
PARALLEL_JOBS=${PARALLEL_JOBS:=$(( $(getconf _NPROCESSORS_ONLN 2> /dev/null || echo 2) * 3 / 4 ))}

# "qtbase qtsvg" -> "qtbase,qtsvg"
join_modules() { echo "$*" | tr -s ' ' ','; }
