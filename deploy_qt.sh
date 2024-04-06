#!/bin/bash
set -e #-x

if [ $# -lt 1 ];
then
  echo "Usage : deploy_qt.sh [QT_PLATFORM_PLUGIN_PATH KOBO_DEVICE_IP]"
  exit
fi

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

QTVERSION=5.15.13 # <= /home/${USER}/qt-bin/qt-linux-5.15-kde-kobo/bin/qmake -query QT_VERSION
QTNAME=5.15-kde
QTVERSIONMAJOR=5

export CROSS_TC=arm-kobo-linux-gnueabihf

export SYSROOT=/home/${USER}/x-tools/${CROSS_TC}/${CROSS_TC}/sysroot
QTBINPATH=/home/${USER}/qt-bin/qt-linux-$QTNAME-kobo

OUTPUTNAME=qt-linux-$QTNAME-kobo
TMPPATH=$DIR/deploy/$OUTPUTNAME
ADDSPATH=$DIR/deploy/libadditions
DEPLOYPATH=/mnt/onboard/.adds/$OUTPUTNAME
PLATFORMPLUGINBUILDPATH=$1

rm -rf $TMPPATH

mkdir $TMPPATH
cp -r -t $TMPPATH $QTBINPATH/plugins $QTBINPATH/qml

mkdir $TMPPATH/lib
cp -t $TMPPATH/lib $QTBINPATH/lib/*.so.$QTVERSION

mmv $TMPPATH/lib/\*.$QTVERSION $TMPPATH/lib/\#1.$QTVERSIONMAJOR

rm -rf $TMPPATH/plugins/platforms/*

cp -t $TMPPATH/plugins/platforms/ ${PLATFORMPLUGINBUILDPATH}/libkobo.so

cp -r -t $TMPPATH/lib $ADDSPATH/*

cp -t $TMPPATH/lib ${SYSROOT}/lib/libstdc++.so.6

cp -t $TMPPATH/lib ${SYSROOT}/usr/lib/libssl.so.3
cp -t $TMPPATH/lib ${SYSROOT}/usr/lib/libcrypto.so.3

cp -t $TMPPATH/lib ${SYSROOT}/usr/lib/libzstd.so.1
cp -t $TMPPATH/lib ${SYSROOT}/usr/lib/libjpeg.so.62
cp -t $TMPPATH/lib ${SYSROOT}/usr/lib/libturbojpeg.so.0
cp -t $TMPPATH/lib ${SYSROOT}/usr/lib/libpng16.so.16

cp -t $TMPPATH/lib ${SYSROOT}/usr/lib/libfreetype.so.6
cp -t $TMPPATH/lib ${SYSROOT}/usr/lib/libharfbuzz.so.0
cp -t $TMPPATH/lib ${SYSROOT}/usr/lib/libpcre2-16.so.0

if [ -z "$2" ];
then
  echo "NO DEVICE IP PROVIDED => NO DEPLOYMENT"
  exit
fi

lftp -u root,123 -p 22 sftp://$2 <<EOF
rm -rf $DEPLOYPATH
mkdir $DEPLOYPATH
mirror -R $TMPPATH $DEPLOYPATH
exit
