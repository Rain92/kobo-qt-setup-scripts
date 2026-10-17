#!/bin/bash
set -e

USAGE="usage: deploy_qt.sh [upload]
Packs the Qt 5 libraries, plugins and the kobo platform plugin into deploy/qt-linux-5.15-kde-kobo.
With 'upload' the folder is mirrored to the device via lftp/sftp
(KOBO_HOST, KOBO_USER and KOBO_PASSWORD from the environment, defaults 192.168.3.123, root, 123)."

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

QTNAME=5.15-kde
QTVERSIONMAJOR=5

CROSS_TC=arm-kobo-linux-gnueabihf
SYSROOT=/home/${USER}/kobo/x-tools/${CROSS_TC}/${CROSS_TC}/sysroot
CROSS=/home/${USER}/kobo/x-tools/${CROSS_TC}/bin/${CROSS_TC}
QTBINPATH=/home/${USER}/kobo/qt-bin/qt-linux-$QTNAME-kobo
# e.g. 5.15.19
QTVERSION=$(sed -n 's/^QT_VERSION = //p' $QTBINPATH/mkspecs/qconfig.pri)

OUTPUTNAME=qt-linux-$QTNAME-kobo
TMPPATH=$DIR/deploy/$OUTPUTNAME
ADDSPATH=$DIR/../deploy/libadditions
DEPLOYPATH=/mnt/onboard/.adds/$OUTPUTNAME
PLATFORMPLUGIN=${PLATFORMPLUGIN:=/home/${USER}/kobo/projects/build-koboplatformplugin-Kobo-Release/libkobo.so}

KOBO_HOST=${KOBO_HOST:=192.168.3.123}
KOBO_USER=${KOBO_USER:=root}
KOBO_PASSWORD=${KOBO_PASSWORD:=123}

do_upload=false
case "$1" in
    upload) do_upload=true
        ;;
    -h|--help) echo "${USAGE}"; exit 0
        ;;
esac

if [ ! -f "$PLATFORMPLUGIN" ]; then
    echo "Kobo platform plugin not found at ${PLATFORMPLUGIN}, set PLATFORMPLUGIN to its path."
    exit 1
fi

rm -rf $TMPPATH
mkdir -p $TMPPATH/lib

cp -r -t $TMPPATH $QTBINPATH/plugins $QTBINPATH/qml

# libQt5Foo.so.5.15.19 -> libQt5Foo.so.5
for lib in $QTBINPATH/lib/*.so.$QTVERSION; do
    name=$(basename $lib)
    cp $lib $TMPPATH/lib/${name%.$QTVERSION}.$QTVERSIONMAJOR
done

rm -rf $TMPPATH/plugins/platforms/*
cp -t $TMPPATH/plugins/platforms/ $PLATFORMPLUGIN

cp -r -t $TMPPATH/lib $ADDSPATH/*

cp -t $TMPPATH/lib ${SYSROOT}/lib/libstdc++.so.6
cp -t $TMPPATH/lib ${SYSROOT}/lib/libgcc_s.so.1

# shared dependencies from the sysroot (see install_libs.sh)
for dep in libssl.so.3 libcrypto.so.3 libz.so.1 libjpeg.so.62 libturbojpeg.so.0 libpng16.so.16 \
           libfreetype.so.6 libharfbuzz.so.0 libpcre2-16.so.0 libzstd.so.1; do
    cp -L -t $TMPPATH/lib ${SYSROOT}/usr/lib/$dep
done

${CROSS}-strip --strip-unneeded $TMPPATH/lib/*.so* $(find $TMPPATH/plugins $TMPPATH/qml -name '*.so') 2>/dev/null || true

echo "Deploy folder: $TMPPATH"

if [ "$do_upload" = true ] ; then
    lftp -u ${KOBO_USER},${KOBO_PASSWORD} -p 22 sftp://${KOBO_HOST} <<EOF
rm -rf $DEPLOYPATH
mkdir $DEPLOYPATH
mirror -R $TMPPATH $DEPLOYPATH
exit
EOF
fi
