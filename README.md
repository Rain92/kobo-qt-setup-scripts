# kobo-qt-setup-scripts

A collection of scripts to setup a development environment for cross compiling Qt apps for Kobo Arm targets.

## Installing the Cross Compiler Toolchain

install_toolchain.sh will install the crosscompiler to the home /home/user/x-tools directory.
It is based on https://github.com/NiLuJe/koxtoolchain, so make sure the necessary dependencies are installed beforehand.
Atfer installing make sure to add the compiler path (/home/${USER}/x-tools/arm-kobo-linux-gnueabihf/bin) to your path variable.

## Installing the Qt dependencies

install_libs.sh will download, patch, compile, and install Qt dependencies.
These are the latest versions of zlib-ng, pnglib, libjpeg-turbo, expat, openssl, pcre, libfreetype and harfbuzz.


## Downloading and installing Qt
get_qt.sh [kobo|desktop] [clean] will download the latest repositories of the KDE branch of Qt 5.15.
Targets are eighter kobo or linux desktop. The deskop version will include some additional libraries like for X11 and Wayland.
The clean flag will clean the repositories if they exist already.


build_qt.sh [kobo|desktop] [config] [make] [install] will configure, compile and/or install the previously downloaded Qt version.
The default install directory is /home/${USER}/qt-bin.

deploy_qt.sh will pack the necassary components of the Qt binaries to a single folder so they can be deployed on the the Kobo device.

## Installing a Debugger
install_gdb.sh will download, compile and install both GDB and GDB-Server for debugging.
GDB will be installed in /home/${USER}/x-tools/arm-kobo-linux-gnueabihf/bin.
GDB-Server will be installed in /home/${USER}/x-tools/arm-kobo-linux-gnueabihf/arm-kobo-linux-gnueabihf/sysroot/usr/bin and has to be transfered to deployed on the Kobo device.

## Docker Image
A docker image with complete environment and a preconfigured Qt Creator can be found here https://github.com/Rain92/kobo-qt-dev-docker.
