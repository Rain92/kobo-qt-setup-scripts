#!/bin/bash
# usage: install_usbnet.sh [kobo mount point]
#        install_usbnet.sh --ssh [root@192.168.2.123]
# Installs usbnet.sh, dropbear, sftp-server and your SSH key with NickelMenu entries on a Kobo
# (mounted as USB drive, or over SSH) and adds a NetworkManager profile for the USB network on this PC.
# NickelMenu itself has to be installed already. For SSH at boot, run once on the Kobo afterwards:
#   sh /mnt/onboard/.adds/usbnet/usbnet.sh install-boot   and rename .kobo/ssh-disabled to ssh-enabled
set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

PUBKEY=${PUBKEY:=${HOME}/.ssh/id_ed25519.pub}

CROSS_TC_PATH=${CROSS_TC_PATH:=${HOME}/kobo/x-tools}
CROSS_TC=arm-kobo-linux-gnueabihf
DROPBEAR_VERSION=DROPBEAR_2026.94
OPENSSH_VERSION=V_10_6_P1
BUILD_DIR=${SCRIPT_DIR}/build
CFLAGS_KOBO="-O2 -march=armv7-a -mtune=cortex-a8 -mfpu=neon -mfloat-abi=hard -mthumb -pipe"

# must match usbnet.sh
KOBO_IP=192.168.2.123
HOST_IP=192.168.2.1
HOST_MAC=46:0D:9E:67:69:EB

if [ "$1" = "--ssh" ]; then
    SSH_TARGET=${2:-root@${KOBO_IP}}
else
    KOBO=${1:-/run/media/${USER}/KOBOeReader}
    if [ ! -d "$KOBO/.kobo" ]; then
        echo "No Kobo mounted at $KOBO (connect it and tap Connect), or use --ssh"
        exit 1
    fi
fi

export PATH=${CROSS_TC_PATH}/${CROSS_TC}/bin:$PATH

# dropbear: root's password and keys, its own scp and OpenSSH's sftp-server in the PATH of ssh sessions
if [ ! -x "$BUILD_DIR/dropbear/dropbearmulti" ]; then
    rm -rf "$BUILD_DIR/dropbear"
    git clone --depth 1 --branch $DROPBEAR_VERSION https://github.com/mkj/dropbear "$BUILD_DIR/dropbear"
    cd "$BUILD_DIR/dropbear"
    # only check the permissions of the key directory, not of every parent (/usr is world writable on Kobos)
    git apply "$SCRIPT_DIR/dropbear-kobo.patch"
    cat > localoptions.h << 'EOF'
#define DEFAULT_PATH "/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/usbnet/bin"
#define DEFAULT_ROOT_PATH "/usr/sbin:/usr/bin:/sbin:/bin:/usr/local/usbnet/bin"
#define SFTPSERVER_PATH "/usr/local/usbnet/bin/sftp-server"
EOF
    CC=${CROSS_TC}-gcc AR=${CROSS_TC}-ar RANLIB=${CROSS_TC}-ranlib CFLAGS="$CFLAGS_KOBO" \
        ./configure --host=${CROSS_TC} --enable-bundled-libtom --disable-zlib --disable-lastlog \
        --disable-utmp --disable-utmpx --disable-wtmp --disable-wtmpx --disable-pututline --disable-pututxline
    make -j$(nproc) PROGRAMS="dropbear dropbearkey scp" MULTI=1
    ${CROSS_TC}-strip dropbearmulti
    cd "$SCRIPT_DIR"
fi

if [ ! -x "$BUILD_DIR/openssh/sftp-server" ]; then
    rm -rf "$BUILD_DIR/openssh"
    git clone --depth 1 --branch $OPENSSH_VERSION https://github.com/openssh/openssh-portable "$BUILD_DIR/openssh"
    cd "$BUILD_DIR/openssh"
    autoreconf -fi
    CC=${CROSS_TC}-gcc AR=${CROSS_TC}-ar RANLIB=${CROSS_TC}-ranlib CFLAGS="$CFLAGS_KOBO" \
        ./configure --host=${CROSS_TC} --without-openssl --without-zlib --without-pam --without-selinux
    make -j$(nproc) sftp-server
    ${CROSS_TC}-strip sftp-server
    cd "$SCRIPT_DIR"
fi

STAGE=$(mktemp -d)
mkdir -p "$STAGE/.adds/usbnet" "$STAGE/.adds/nm"
cp "$SCRIPT_DIR/usbnet.sh" "$BUILD_DIR/dropbear/dropbearmulti" "$BUILD_DIR/openssh/sftp-server" "$STAGE/.adds/usbnet/"
cp "$PUBKEY" "$STAGE/.adds/usbnet/authorized_keys"

cat > "$STAGE/.adds/nm/usbnet" << 'EOF'
# USB network with SSH (see .adds/usbnet/usbnet.sh), cancel Nickel's USB connect dialog first
menu_item :main :USB Network :cmd_output :9000 :/bin/sh /mnt/onboard/.adds/usbnet/usbnet.sh toggle
EOF

# NickelMenu reads its configs in file name order: usbnet, usbnet-wifi, then webui-preset of the
# KoboPatch Web UI (Typography), zz-power (Reboot) comes last
cat > "$STAGE/.adds/nm/usbnet-wifi" << 'EOF'
# Keep WiFi On: toggles DeveloperSettings.ForceWifiOn, which only applies after WiFi was turned off and on
menu_item :main :Keep WiFi On :nickel_setting :toggle :force_wifi
  chain_success :cmd_output :1000:quiet :/bin/grep -q "^ForceWifiOn=true" "/mnt/onboard/.kobo/Kobo/Kobo eReader.conf"
  chain_failure :skip:5
    chain_success :nickel_wifi :disable
    chain_success :cmd_output :3000:quiet :/bin/sleep 2
    chain_success :nickel_wifi :autoconnect
    chain_success :dbg_toast :Keep WiFi On: on
    chain_always :skip:-1
  chain_always :dbg_toast :Keep WiFi On: off
EOF

cat > "$STAGE/.adds/nm/zz-power" << 'EOF'
menu_item :main :Reboot :power :reboot
EOF

# configs of earlier versions of this script
OLD_NM_CONFIGS=".adds/nm/wifi .adds/nm/power"

if [ -n "$SSH_TARGET" ]; then
    # FAT has no permissions/owners; stage the binaries next to the running ones, usbnet.sh swaps them
    tar -C "$STAGE" -cf - .adds | ssh "$SSH_TARGET" \
        "cd /mnt/onboard && rm -f $OLD_NM_CONFIGS && tar -xf - 2>/dev/null; sync"
    echo "Installed to $SSH_TARGET:/mnt/onboard/.adds/usbnet"
else
    (cd "$KOBO" && rm -f $OLD_NM_CONFIGS)
    cp -r "$STAGE/.adds/." "$KOBO/.adds/"
    sync
    echo "Installed to $KOBO/.adds/usbnet"
fi
rm -rf "$STAGE"

# PC side: static address on the Kobo's USB interface, matched by the gadget's host MAC
if command -v nmcli > /dev/null; then
    if ! nmcli -t -f NAME connection show | grep -qx kobo-usbnet; then
        nmcli connection add type ethernet con-name kobo-usbnet ethernet.mac-address $HOST_MAC \
            ipv4.method manual ipv4.addresses $HOST_IP/24 ipv4.never-default yes ipv6.method disabled \
            connection.autoconnect yes
        echo "NetworkManager profile kobo-usbnet added ($HOST_IP)"
    fi
else
    echo "Give the Kobo's USB interface ($HOST_MAC) the address $HOST_IP/24"
fi

echo "On the Kobo: cancel the USB connect dialog, then NickelMenu > USB Network. Then: ssh root@$KOBO_IP"
