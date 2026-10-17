#!/bin/bash
# Usage: install_toolchain.sh [source]
# Installs the koxtoolchain Kobo cross compiler (GCC 14, glibc 2.15) to ~/kobo/x-tools.
# By default the prebuilt KOReader release is downloaded, "source" builds it with crosstool-NG instead.
set -e

LIBDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

# release tag of https://github.com/koreader/koxtoolchain, keep the koxtoolchain submodule on the same tag
KOXTOOLCHAIN_VERSION=${KOXTOOLCHAIN_VERSION:=2026.08}

CROSS_TC_PATH=${CROSS_TC_PATH:=${HOME}/kobo/x-tools}
CROSS_TC=arm-kobo-linux-gnueabihf

if [ -e ${CROSS_TC_PATH}/${CROSS_TC} ]; then
    echo "${CROSS_TC_PATH}/${CROSS_TC} already exists, move it away first"
    exit 1
fi
mkdir -p ${CROSS_TC_PATH}

if [ "$1" = "source" ]; then
    # gen-tc.sh always installs to ~/x-tools
    ${LIBDIR}/koxtoolchain/gen-tc.sh kobo
    if [ "${HOME}/x-tools" != "${CROSS_TC_PATH}" ]; then
        chmod -R u+w ${HOME}/x-tools/${CROSS_TC}
        mv ${HOME}/x-tools/${CROSS_TC} ${CROSS_TC_PATH}/
    fi
else
    curl -fL https://github.com/koreader/koxtoolchain/releases/download/${KOXTOOLCHAIN_VERSION}/kobo.tar.zst \
        | tar --zstd -x -C ${CROSS_TC_PATH} --strip-components=1 x-tools/${CROSS_TC}
fi

# crosstool-NG makes the toolchain read-only, but install_libs.sh installs into its sysroot
chmod -R u+rwx ${CROSS_TC_PATH}/${CROSS_TC}

echo "Installed $(${CROSS_TC_PATH}/${CROSS_TC}/bin/${CROSS_TC}-gcc --version | head -1)"
echo "Add ${CROSS_TC_PATH}/${CROSS_TC}/bin to your PATH, then run install_libs.sh"
