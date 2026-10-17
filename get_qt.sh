#!/bin/bash
set -e

USAGE="usage: get_qt.sh [clean]
Clones Qt \${QT_VERSION} (default from config.sh) and applies the Kobo patches."

source "$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )/config.sh"

clean=false
while test $# -gt 0
do
    case "$1" in
        clean) clean=true
            ;;
        -h|--help) echo "${USAGE}"; exit 0
            ;;
        *) echo "unknown argument: $1"; echo "${USAGE}"; exit 1
            ;;
    esac
    shift
done

if [ ! -d "$SRC_DIR" ]; then
    git clone --branch v${QT_VERSION} --depth 1 $QT_REPO $SRC_DIR
fi

cd $SRC_DIR

# Shallow clones of the needed submodules only; github mirrors allow fetching pinned commits by sha.
git submodule update --init --recursive --depth 1 --jobs 8 $QT_MODULES_KOBO

for mod in $QT_MODULES_KOBO; do
    git -C $mod reset --hard
    if [ "$clean" = true ] ; then
        git -C $mod clean -fdx
    fi
done

# Patches are per qt minor version, e.g. patches/qtbase-6.12.patch
QT_MINOR_VERSION=${QT_VERSION%.*}
for mod in $QT_MODULES_KOBO; do
    patch="${SCRIPT_DIR}/patches/${mod}-${QT_MINOR_VERSION}.patch"
    if [ -f "$patch" ]; then
        git -C $mod apply --verbose "$patch"
    fi
done

# Device mkspec, needed for qmake based projects built against the kobo Qt
cp -r "${SCRIPT_DIR}/mkspecs/devices/${CROSS_TC}-g++" qtbase/mkspecs/devices/
