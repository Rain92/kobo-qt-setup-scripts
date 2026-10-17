#!/bin/sh
# USB network and SSH (dropbear) for Kobo devices.
# usage: usbnet.sh [start|stop|toggle]   USB network, from NickelMenu
#        usbnet.sh ssh                   SSH on all interfaces (WiFi + USB), from /etc/init.d/ssh at boot
#        usbnet.sh install-boot          make Kobo's SSH switch (.kobo/ssh-enabled) start dropbear
#
# The USB network loads the USB ethernet gadget of the stock kernel and gives the Kobo KOBO_IP on usb0.
# Nickel's "Connect" (mass storage) uses the same USB controller, cancel that dialog first.
# dropbear accepts root's password and the keys in authorized_keys, scp and sftp work.

DIR=/mnt/onboard/.adds/usbnet
# dropbear checks the permissions of the key directory, the runtime copy lives on the root filesystem
RUN=/usr/local/usbnet
LOG=$DIR/usbnet.log

KOBO_IP=192.168.2.123
# fixed MACs so the PC side can match its network profile on them
HOST_MAC=46:0d:9e:67:69:eb
DEV_MAC=46:0d:9e:67:69:ec

# dropbear started by the ssh command (all interfaces) or for the USB network only
SSH_PID=$RUN/dropbear-ssh.pid
USB_PID=$RUN/dropbear.pid

# processes started by Nickel may run with umask 0
umask 022

log() {
    echo "$(date '+%F %T') $*" >> "$LOG"
}

is_running() {
    [ -f "$1" ] && kill -0 "$(cat "$1")" 2>/dev/null
}

gadget_dir() {
    # rcS exports PLATFORM (e.g. mx6sl-ntx), otherwise look for the driver directory
    if [ -n "$PLATFORM" ] && [ -d "/drivers/$PLATFORM/usb/gadget" ]; then
        echo "/drivers/$PLATFORM/usb/gadget"
        return
    fi
    for d in /drivers/*/usb/gadget; do
        if [ -e "$d/g_ether.ko" ]; then
            echo "$d"
            return
        fi
    done
}

# <pid file> <dropbear -p argument>
start_dropbear() {
    mkdir -p $RUN/bin $RUN/keys
    chmod 755 $RUN $RUN/bin
    chmod 700 $RUN/keys
    for f in dropbearmulti sftp-server; do
        # never overwrite the binary of a running dropbear
        cmp -s $DIR/$f $RUN/bin/$f || { cp $DIR/$f $RUN/bin/$f.new && mv $RUN/bin/$f.new $RUN/bin/$f; }
        chmod 755 $RUN/bin/$f
    done
    for p in dropbear dropbearkey scp; do
        ln -sf dropbearmulti $RUN/bin/$p
    done
    # the host key is kept on the FAT partition so it survives firmware updates
    if [ ! -s $DIR/dropbear_ed25519_host_key ]; then
        $RUN/bin/dropbearkey -t ed25519 -f $RUN/keys/dropbear_ed25519_host_key >> "$LOG" 2>&1
        cp $RUN/keys/dropbear_ed25519_host_key $DIR/dropbear_ed25519_host_key
    fi
    cp $DIR/dropbear_ed25519_host_key $DIR/authorized_keys $RUN/keys/
    chmod 600 $RUN/keys/*

    # interactive logins need ptys
    if ! grep -q ' /dev/pts ' /proc/mounts; then
        mkdir -p /dev/pts
        mount -t devpts devpts /dev/pts
    fi

    # Kobo's own sshd would block port 22 (and crashes during the key exchange on older kernels)
    if pidof sshd > /dev/null; then
        log "stopping Kobo's sshd, it blocks port 22"
        kill $(pidof sshd)
        sleep 1
    fi

    $RUN/bin/dropbear -r $RUN/keys/dropbear_ed25519_host_key -D $RUN/keys -p "$2" -P "$1" -E \
        >> "$LOG" 2>&1 < /dev/null
    # dropbear writes the pid file after forking into the background
    for i in 1 2 3 4 5; do
        is_running "$1" && return 0
        sleep 1
    done
    return 1
}

ssh_start() {
    log "ssh"
    if is_running $SSH_PID; then
        return 0
    fi
    # the USB-only dropbear would block port 22 on usb0
    if is_running $USB_PID; then
        kill "$(cat $USB_PID)"
        rm -f $USB_PID
        sleep 1
    fi
    if start_dropbear $SSH_PID 22; then
        log "ssh running on all interfaces"
        echo "SSH is ON (all interfaces)"
    else
        log "dropbear did not start"
        echo "SSH: dropbear did not start, see .adds/usbnet/usbnet.log"
        return 1
    fi
}

usb_start() {
    log "start"
    GADGET=$(gadget_dir)
    if [ -z "$GADGET" ]; then
        log "no USB gadget drivers found in /drivers"
        echo "USB network: gadget drivers not found, see .adds/usbnet/usbnet.log"
        return 1
    fi

    # the mass storage gadget occupies the controller
    if grep -q '^g_file_storage ' /proc/modules; then
        rmmod g_file_storage >> "$LOG" 2>&1
    fi
    # the controller driver is built into some kernels (insmod fails with "short read" there)
    if ! grep -q '^arcotg_udc ' /proc/modules && [ -s "$GADGET/arcotg_udc.ko" ]; then
        insmod "$GADGET/arcotg_udc.ko" >> "$LOG" 2>&1 || log "arcotg_udc not loaded, assuming it is built in"
    fi
    if ! grep -q '^g_ether ' /proc/modules; then
        insmod "$GADGET/g_ether.ko" host_addr=$HOST_MAC dev_addr=$DEV_MAC >> "$LOG" 2>&1
    fi
    if ! ifconfig usb0 $KOBO_IP netmask 255.255.255.0 up >> "$LOG" 2>&1; then
        log "usb0 did not come up, loaded modules:"
        cat /proc/modules >> "$LOG"
        echo "USB network: usb0 did not come up, see .adds/usbnet/usbnet.log"
        return 1
    fi

    # the dropbear started at boot already listens on all interfaces
    if is_running $SSH_PID || is_running $USB_PID || start_dropbear $USB_PID $KOBO_IP:22; then
        log "running on $KOBO_IP"
        echo "USB network is ON: ssh root@$KOBO_IP"
    else
        log "dropbear did not start"
        echo "USB network: usb0 is up but dropbear did not start, see .adds/usbnet/usbnet.log"
        return 1
    fi
}

usb_stop() {
    log "stop"
    if is_running $USB_PID; then
        kill "$(cat $USB_PID)"
    fi
    rm -f $USB_PID
    ifconfig usb0 down >> "$LOG" 2>&1
    for m in g_ether arcotg_udc; do
        if grep -q "^$m " /proc/modules; then
            rmmod $m >> "$LOG" 2>&1
        fi
    done
    echo "USB network is OFF"
}

install_boot() {
    local init=/etc/init.d/ssh
    if grep -q 'usbnet.sh ssh' $init; then
        echo "$init already starts dropbear"
        return 0
    fi
    [ -f $init.kobo-orig ] || cp -p $init $init.kobo-orig
    # replace the start of Kobo's sshd, everything before it (password handling, flags) stays
    sed -i "s#^/usr/sbin/sshd\$#/bin/sh $DIR/usbnet.sh ssh || /usr/sbin/sshd#" $init
    if grep -q 'usbnet.sh ssh' $init; then
        echo "$init now starts dropbear (original in $init.kobo-orig)"
    else
        echo "could not patch $init"
        return 1
    fi
}

case "$1" in
    start) usb_start ;;
    stop) usb_stop ;;
    ssh) ssh_start ;;
    install-boot) install_boot ;;
    *) if grep -q '^g_ether ' /proc/modules; then usb_stop; else usb_start; fi ;;
esac
