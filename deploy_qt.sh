#!/bin/bash
set -e

USAGE="usage: deploy_qt.sh [upload]
Packs the Qt \${QT_VERSION} libraries, plugins and the kobo platform plugin into deploy/qt-\${QT_VERSION}-kobo.
With 'upload' the folder is mirrored to \${KOBO_DEVICE_PREFIX} on the device via lftp/sftp
(KOBO_HOST, KOBO_USER and KOBO_PASSWORD from the environment)."

source "$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )/config.sh"

QT_MAJOR_VERSION=${QT_VERSION%%.*}

OUTPUTNAME=qt-${QT_VERSION}-kobo
TMPPATH=${SCRIPT_DIR}/deploy/${OUTPUTNAME}
ADDSPATH=${SCRIPT_DIR}/deploy/libadditions
PLATFORMPLUGIN=${PLATFORMPLUGIN:=/home/${USER}/kobo/projects/qt6-kobo-platform-plugin/build-kobo-qt6-release/libkobo.so}

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

cp -r -t $TMPPATH ${KOBO_STAGING_PREFIX}/plugins
[ -d ${KOBO_STAGING_PREFIX}/qml ] && cp -r -t $TMPPATH ${KOBO_STAGING_PREFIX}/qml
[ -d ${KOBO_STAGING_PREFIX}/translations ] && cp -r -t $TMPPATH ${KOBO_STAGING_PREFIX}/translations

# libQt6Foo.so.6.12.0 -> libQt6Foo.so.6
for lib in ${KOBO_STAGING_PREFIX}/lib/libQt*.so.${QT_VERSION}; do
    name=$(basename $lib)
    cp $lib $TMPPATH/lib/${name%.${QT_VERSION}}.${QT_MAJOR_VERSION}
done

rm -rf $TMPPATH/plugins/platforms/*
cp -t $TMPPATH/plugins/platforms/ $PLATFORMPLUGIN

cp -r -t $TMPPATH/lib $ADDSPATH/*

cp -t $TMPPATH/lib ${SYSROOT}/lib/libstdc++.so.6
cp -t $TMPPATH/lib ${SYSROOT}/lib/libgcc_s.so.1

# Shared dependencies from the sysroot (see install_libs.sh), turbojpeg for apps; OpenSSL is linked statically
for dep in libz.so.1 libpng16.so.16 libjpeg.so.62 libturbojpeg.so.0 libfreetype.so.6 libharfbuzz.so.0 libpcre2-16.so.0 libzstd.so.1; do
    cp -L -t $TMPPATH/lib ${SYSROOT}/usr/lib/$dep
done

${CROSS}-strip --strip-unneeded $TMPPATH/lib/*.so* $(find $TMPPATH/plugins $TMPPATH/qml -name '*.so' 2>/dev/null) 2>/dev/null || true

echo "Deploy folder: $TMPPATH"

if [ "$do_upload" = true ] ; then
    KOBO_HOST=${KOBO_HOST:?set KOBO_HOST to the device ip}
    KOBO_USER=${KOBO_USER:=root}
    lftp -u ${KOBO_USER},${KOBO_PASSWORD} -p 22 sftp://${KOBO_HOST} <<EOF
rm -rf $KOBO_DEVICE_PREFIX
mkdir $KOBO_DEVICE_PREFIX
mirror -R $TMPPATH $KOBO_DEVICE_PREFIX
exit
EOF
fi
