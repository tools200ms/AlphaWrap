#!/bin/bash -l
# Based on: https://wiki.alpinelinux.org/wiki/Alpine_Linux_in_a_chroot

if [ -n "$PRETEND" ] && [[ $(echo "$PRETEND" | tr '[:upper:]' '[:lower:]') =~ ^y|yes|1|on$ ]]; then
  RUN="echo"
else
  RUN=
fi

[ -n "$DEBUG" ] && [[ $(echo "$DEBUG" | tr '[:upper:]' '[:lower:]') =~ ^y|yes|1|on$ ]] && \
        set -xe -o pipefail || set -e -o pipefail


function print_help() {
  local indent_cnt=$(basename $0 | wc -c)
  local indent_p1=$(printf "%*s" "$indent_cnt" "")

  cat <<EOF
Usage:
$(basename $0) super_light | sl    <device>
${indent_p1}just_light  | jl    <device>
${indent_p1}be_desktop  | bd    <device>

  AlpBase edition for installation: Super Light, Just Light, BeDesktop
  <device> - block device for installation of a selected edition

$(basename $0) updates|u
  Check if Alpine updates are avaliable. If so, updates are installed
  and '0' is returned. Otherwise, 'non-zero' exit code is returned.

$(basename $0) help
  Print this help and exit.

EOF
}

function require_root() {
  if [ -z $RUN ] && [ $(id -u) -ne 0 ]; then
    echo "Run it as root!"
    exit 0
  fi
}

# ensure tailing '/' is always here ending 'stat -c %i /proc/1/root/'
# '/proc/1/root' points to a symbolic link that is not what we check,
# we check inode of the directory that symbolic link is pointing to.
function require_chroot() {
  if [ -z $RUN ] && [ $(stat -c %i /) -eq $(stat -c %i /proc/1/root/) ]; then
    echo "We are not in chroot environment, nothing to do."
    exit 0
  fi
}

CACHE_TIMESTAMP_FILE="/var/tmp/ab_builder_update_timestamp"
CACHE_DURATION=$((60 * 60))  # 1 hour in seconds

function update_frequency_limit_check() {
    # If the cache file does not exist, or if it's more than an hour old
    if [[ ! -f "$CACHE_TIMESTAMP_FILE" ]] || (( $(date +%s) - $(cat "$CACHE_TIMESTAMP_FILE") >= CACHE_DURATION )); then
      # Update cache timestamp
      date +%s > "$CACHE_TIMESTAMP_FILE"
      return 0  # Indicates cache is expired or does not exist
    else
      return 1  # Indicates cache is still valid
    fi
}


readonly RES_DIR=$(dirname $0)/files

MODE=$1
SETUP_DEV=$2

if [[ "$MODE" == "u" || "$MODE" == "updates" ]]; then

  if ! update_frequency_limit_check; then
    exit 1
  fi

  # if updates available
  apk update
  if [ $(apk version -a | wc -l) -ne 1 ]; then
    apk upgrade
    exit 0
  fi
  exit 1
fi

if [[ "$MODE" == "-h" || "$MODE" == "--help" || "$MODE" == "help" ]]; then
    print_help
    exit 0
fi

require_root && require_chroot

# calidate parameters:
case $MODE in
  super_light|sl)
    EDITION=super_light
    EDITION_SHORT=sl
  ;;
  just_light|jl)
    EDITION=just_light
    EDITION_SHORT=jl
  ;;
  be_desktop|bd)
    EDITION=be_desktop
    EDITION_SHORT=bd
  ;;
  [a-zA-Z0-9_-]*)
    echo "Unknown edition: $MODE"
    exit 1
  ;;
  *)
    echo "Incorrect syntax, --help, for help"
    exit 2
  ;;
esac

if [ -z "${SETUP_DEV}" ] || [ ! -b "${SETUP_DEV}" ]; then
  echo "Provide block device"
  exit 3
fi

# Standard mount point, the same that is used by setup-disk
readonly SETUP_ROOT=/mnt
#/setup_${EDITION_SHORT}

# === 0.1: Set settings specific for setup:
case $EDITION in
  super_light)
    # for one CPU core
    DEVD=mdev
    ROOTFS=ext4
    #jffs2
    NTP=none
    SSHD=dropbear
    DESKTOP=none
  ;;
  just_light)
    # multi-core CPU:
    DEVD=mdevd
    ROOTFS=ext4
    #jffs2
    NTP=busybox
    SSHD=dropbear
    DESKTOP=none
  ;;
  be_desktop)
    # fancy features
    DEVD=udev
    ROOTFS=ext4
    #f2fs
    NTP=chrony
    SSHD=dropbear
    DESKTOP=standard
  ;;
  iam_tablet)
    DEVD=mdevd
    ROOTFS=jffs2
    SSHD=dropbear
    DESKTOP=tablet
  ;;
  *)
    echo "This should not happen"
    exit 222
  ;;
esac

readonly LOG_FILE=/var/log/alpbase_alpine-setup-$EDITION.log
echo "Installing: $EDITION edition"
echo ""

#rc-update add devfs sysinit
#rc-update add dmesg sysinit
#rc-update add mdev sysinit

#rc-update add hwclock boot
#rc-update add modules boot
#rc-update add sysctl boot
#rc-update add hostname boot
#rc-update add bootmisc boot
#rc-update add syslog boot

#rc-update add mount-ro shutdown
#rc-update add killprocs shutdown
#rc-update add savecache shutdown

# === 1: Install base:
# this script (for installation) does mount ${SETUP_DEV} under '/mnt'
setup-disk ${SETUP_DEV} <<EOF | tee ${LOG_FILE}
sys
y
EOF

# === 1.1: mount installed base (again):
$RUN mkdir -p ${SETUP_ROOT}
$RUN mount ${SETUP_DEV}2 ${SETUP_ROOT}
$RUN mount ${SETUP_DEV}1 ${SETUP_ROOT}/boot


# === 1.2: Copy setup and add edition specific settings:
$RUN cat $RES_DIR/setup | \
      sed "/Edition\ specific\ variable\ declarations/c\EDITION=${EDITION}\; DEVD=${DEVD}\; NTP=${NTP}\; DESKTOP=${DESKTOP}" \
      > ${SETUP_ROOT}/etc/init.d/setup && chmod +x ${SETUP_ROOT}/etc/init.d/setup

$RUN cat $RES_DIR/setup-msg > ${SETUP_ROOT}/etc/init.d/setup-msg && chmod +x ${SETUP_ROOT}/etc/init.d/setup-msg
$RUN cat $RES_DIR/setup-finish > ${SETUP_ROOT}/usr/local/bin/setup-finish && chmod +x ${SETUP_ROOT}/usr/local/bin/setup-finish

# === 1.3: Bind system directories for jumping into chroot:
chroot_bind.sh system ${SETUP_ROOT}

# === 2. Prepare edition:

chroot ${SETUP_ROOT} rc-update add setup boot

# 'setup-devd' does device scanning, hence install only necessary
# packages and let to scann devices at a final device
case $DEVD in
  mdev)
    chroot ${SETUP_ROOT} apk add --quiet busybox-mdev-openrc
  ;;
  mdevd)
    # only install package, configuration will be done by 'setup' script
    chroot ${SETUP_ROOT} apk add --quiet mdevd mdevd-openrc
  ;;
  udev)
    #
    chroot ${SETUP_ROOT} apk add --quiet eudev udev-init-scripts udev-init-scripts-openrc
  ;;
  *)
    echo "This should not happen"
    exit 222
  ;;
esac

case $ROOTFS in
  ext4)
    chroot ${SETUP_ROOT} apk add e2fsprogs-extra
  ;;
  jffs2)
    # mkfs.jffs2: Used to create a JFFS2 filesystem.
    # jffs2dump: Dumps the contents of a JFFS2 filesystem.
    # sumtool: Generates a summary for faster mounting of JFFS2.

    chroot ${SETUP_ROOT} apk add mtd-utils
  ;;
  f2fs)
    chroot ${SETUP_ROOT} apk add f2fs-tools
  ;;
  *)
    echo "This should not happen"
    exit 222
  ;;
esac

case $NTP in
  chrony)
    echo "Install"
  ;;
esac

# create user
setup-user -a master

case $SSHD in
  dropbear)
    chroot ${SETUP_ROOT} apk add dropbear
  ;;
  openssh)
    chroot ${SETUP_ROOT} apk add openssh
  ;;
esac

# === 2.2. Install desktop if applicable:
if [ -n "$DESKTOP" ] && [ $DESKTOP != "none" ]; then
  # gnome||
  case $DESKTOP in
    tablet)
      DESKTOP_TYPE=sway
    ;;
    light)
      DESKTOP_TYPE=xfce
    ;;
    standard)
      DESKTOP_TYPE=mate
      #plasma
    ;;
    *)
      echo "This should not happen"
      exit 222
    ;;
  esac

  echo "Desktop to be installed: $DESKTOP_TYPE"
  chroot ${SETUP_ROOT} setup-desktop $DESKTOP_TYPE | tee ${LOG_FILE}
fi

# y - to scann for devices
#chroot ${SETUP_ROOT} setup-devd <<EOF | tee ${LOG_FILE}
#$DEVD
#n
#EOF

# make corrections:
BOOT_UUID=$(blkid -s UUID -o value ${SETUP_DEV}1)
ROOT_UUID=$(blkid -s UUID -o value ${SETUP_DEV}2)
BOOT_UUID=${BOOT_UUID} ROOT_UUID=${ROOT_UUID} fstab.gen > /mnt/etc/fstab.new

chroot_bind.sh --unbind system ${SETUP_ROOT}
umount ${SETUP_ROOT}/boot
umount ${SETUP_ROOT}

$RUN sync

echo "Installation done."

exit 0

setup-hostname <<EOF
name
EOF

setup-user <<EOF
EOF

# /sbin/setup-acf # mini web server

/sbin/setup-apkcache
/sbin/setup-apkrepos


/sbin/setup-desktop

/sbin/setup-interfaces
/sbin/setup-dns

/sbin/setup-lbu
/sbin/setup-mta
/sbin/setup-ntp
/sbin/setup-proxy
/sbin/setup-sshd

# at first login:
setup-keymap
setup-timezone
/sbin/setup-hostname

/sbin/setup-wayland-base


exit 0
