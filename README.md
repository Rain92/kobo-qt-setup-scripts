# kobo-qt-setup-scripts

A collection of scripts to setup a development environment for cross compiling Qt apps for Kobo Arm targets.

## Installing the Cross Compiler Toolchain

install_toolchain.sh will install the cross compiler (GCC 14, glibc 2.15, runs on all Kobo devices) to /home/${USER}/kobo/x-tools.
It downloads the prebuilt `kobo` toolchain of https://github.com/koreader/koxtoolchain (release tag set in the script).
`install_toolchain.sh source` builds the same toolchain from the koxtoolchain submodule instead, make sure its dependencies are installed beforehand.
After installing make sure to add the compiler path (/home/${USER}/kobo/x-tools/arm-kobo-linux-gnueabihf/bin) to your path variable.
The libs from install_libs.sh are installed into the toolchain sysroot, so run it again after replacing the toolchain.

## Installing the Qt dependencies

install_libs.sh [lib ...] will download, patch, compile, and install Qt dependencies into the toolchain sysroot.
These are zlib-ng, libb2, zstd, openssl (3.5 LTS), libpng, libjpeg-turbo, expat, pcre2, freetype and harfbuzz.
The versions are pinned to upstream release tags at the top of the script, bump them there to update.
Without arguments everything is built, otherwise only the given libs (e.g. `./install_libs.sh openssl harfbuzz`).
Building harfbuzz needs meson and ninja on the host.


## Downloading and building Qt
The scripts build Qt 6 (6.12.0 by default, set `QT_VERSION` to change it, all settings are in `config.sh`):

```
./get_qt.sh        # shallow clone of the needed modules + Kobo patches (patches/<module>-<major.minor>.patch)
./build_host.sh    # host Qt providing the build tools (moc, rcc, qsb, qmlcachegen, ...)
./build_qt.sh      # cross compiled Qt, staged in ~/kobo/qt-bin/qt-6.12.0-kobo
./deploy_qt.sh     # pack libs, plugins and the kobo platform plugin into deploy/
```

qmake projects can be built with `~/kobo/qt-bin/qt-6.12.0-kobo/bin/qmake`, CMake projects with `.../bin/qt-cmake`.
`deploy_qt.sh` takes the kobo platform plugin ([qt6-kobo-platform-plugin](https://github.com/Rain92/qt6-kobo-platform-plugin))
from `~/kobo/projects/qt6-kobo-platform-plugin/build-kobo-qt6-release/libkobo.so`, `PLATFORMPLUGIN` sets another path.
`deploy_qt.sh upload` mirrors the result to the device (`KOBO_HOST`, `KOBO_USER`, `KOBO_PASSWORD`).

## Qt 5
The scripts for the old Qt 5 are in `qt5/`, with its sources, builds and deploy folder there too.

qt5/get_qt.sh [kobo|desktop] [clean] will download the latest version of the KDE Qt 5.15 patch collection (5.15.19 at the time of writing).
Targets are either kobo or linux desktop. The desktop version will include some additional libraries like for X11 and Wayland.
The clean flag will clean the repositories if they exist already.

qt5/build_qt.sh [kobo|desktop] [config] [make] [install] will configure, compile and/or install the previously downloaded Qt version.
The default install directory is /home/${USER}/kobo/qt-bin.

qt5/deploy_qt.sh [upload] will pack the necessary components of the Qt binaries and the kobo platform plugin (`PLATFORMPLUGIN`) to a single folder (`qt5/deploy/`) so they can be deployed on the Kobo device.
`qt5/deploy_qt.sh upload` also mirrors the folder to the device (`KOBO_HOST`, `KOBO_USER`, `KOBO_PASSWORD`).

## Installing a Debugger
install_gdb.sh will download, compile and install both GDB and GDB-Server for debugging.
A host gdb built with `--enable-targets=all` (e.g. the Arch Linux package) can be used instead of the cross GDB.
GDB will be installed in /home/${USER}/x-tools/arm-kobo-linux-gnueabihf/bin.
GDB-Server will be installed in /home/${USER}/x-tools/arm-kobo-linux-gnueabihf/arm-kobo-linux-gnueabihf/sysroot/usr/bin and has to be transfered to deployed on the Kobo device.

## Docker Image
A docker image with complete environment and a preconfigured Qt Creator can be found here https://github.com/Rain92/kobo-qt-dev-docker.
