#!/bin/bash
set -e

USAGE="usage: get_qt.sh [kobo|desktop] [clean]"

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

REPO=https://invent.kde.org/qt/qt/qt5
LOCALREPO_KOBO="${SCRIPT_DIR}/qt-linux-5.15-kde-kobo"
LOCALREPO_DESKTOP="${SCRIPT_DIR}/qt-linux-5.15-kde-desktop"
BRANCH=kde/5.15

PATCH_PATH="${SCRIPT_DIR}/patches/qt5.15.patch"

MODULES_BASE="qtbase qtcharts qtdeclarative qtgraphicaleffects qtimageformats qtnetworkauth qtquickcontrols2 qtsvg qtwebsockets"
MODULES_DESKTOP="qttools qttranslations qtx11extras qtwayland"

platform=kobo
modules=$MODULES_BASE
localrepo=$LOCALREPO_KOBO
clean=false


if [ $# -lt 1 ]; then
	echo "Missing platform argument, defaulting to kobo"
fi
case  ${1:-kobo} in
    kobo)
        platform=kobo
        modules=$MODULES_BASE
        localrepo=$LOCALREPO_KOBO
        ;;
    desktop)
        platform=desktop
        modules="$MODULES_BASE $MODULES_DESKTOP"
        localrepo=$LOCALREPO_DESKTOP
        ;;
    *)
        echo "[!] $platform not supported!"
        echo "${USAGE}"
        exit 1
        ;;
esac

while test $# -gt 0
do
    case "$1" in
        clean) clean=true
            ;;
        *)
            ;;
    esac
    shift
done


if [ -d "$localrepo" ]; then
    echo "Directory exists. Updating repo..."
    git -C $localrepo pull
else
    git clone --branch $BRANCH $REPO $localrepo 
fi

cd $localrepo

git reset --hard
if [ "$clean" = true ] ; then
    git clean -fdx
fi

for mod in $modules; do
    git submodule update --init --remote -- $mod
    cd $mod
    git reset --hard
    if [ "$clean" = true ] ; then
        git clean -fdx
    fi
    cd ..
done

git -C qtbase apply --verbose $PATCH_PATH
