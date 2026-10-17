#!/bin/bash
set -e

USAGE="usage: build_host.sh
Builds the host Qt \${QT_VERSION} that provides the build tools for cross compiling (moc, rcc, qsb, ...)."

source "$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )/config.sh"

if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
    echo "${USAGE}"
    exit 0
fi

rm -rf $HOST_BUILD_DIR
mkdir $HOST_BUILD_DIR
cd $HOST_BUILD_DIR

# Bundled md4c: a foreign copy (e.g. from /opt/cuda) on the host can be ABI incompatible.
${SRC_DIR}/configure -release -nomake examples -nomake tests \
 -prefix $HOST_PREFIX \
 -submodules $(join_modules $QT_MODULES_HOST) \
 -no-feature-clang -no-feature-qdoc \
 -qt-libmd4c

cmake --build . --parallel $PARALLEL_JOBS
cmake --install .
