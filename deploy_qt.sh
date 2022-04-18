#!/bin/sh
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

QTVERSION=5.15.3
QTNAME=5.15-kde
QTVERSIONMAJOR=5

export CROSS_TC=arm-kobo-linux-gnueabihf

export SYSROOT=/home/${USER}/x-tools/${CROSS_TC}/${CROSS_TC}/sysroot
QTBINPATH=/home/${USER}/qt-bin/qt-linux-$QTNAME-kobo

OUTPUTNAME=qt-linux-$QTNAME-kobo
TMPPATH=$DIR/deploy/$OUTPUTNAME
ADDSPATH=$DIR/deploy/libadditions
DEPLOYPATH=/mnt/onboard/.adds/$OUTPUTNAME
PLATFORMPLUGINBUILDPATH=/home/${USER}/Desktop/qtproject/build-koboplatformplugin-Kobo-Release

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

cp -t $TMPPATH/lib ${SYSROOT}/usr/lib/libz.so.1
cp -t $TMPPATH/lib ${SYSROOT}/usr/lib/libjpeg.so.62 
cp -t $TMPPATH/lib ${SYSROOT}/usr/lib/libturbojpeg.so.0 
cp -t $TMPPATH/lib ${SYSROOT}/usr/lib/libpng16.so.16

cp -t $TMPPATH/lib ${SYSROOT}/usr/lib/libfreetype.so.6
cp -t $TMPPATH/lib ${SYSROOT}/usr/lib/libharfbuzz.so.0
cp -t $TMPPATH/lib ${SYSROOT}/usr/lib/libpcre2-16.so.0



lftp -u root,123 -p 22 sftp://192.168.3.123 <<EOF
rm -rf $DEPLOYPATH
mkdir $DEPLOYPATH
mirror -R $TMPPATH $DEPLOYPATH
exit
EOF

