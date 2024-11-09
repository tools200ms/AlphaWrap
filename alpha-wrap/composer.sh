#!/bin/sh

# Function to check flags for pretend or debug mode
check_flag() {
    [ -n "$1" ] && echo "$1" | tr '[:upper:]' '[:lower:]' | grep -Eq '^y|yes|1|on$'
}

# Set RUN and CHROOTM_EXEC based on flags
[ "$(check_flag "$PRETEND")" ] && RUN="echo" || RUN=""
[ "$(check_flag "$DEBUG")" ] && set -xe && CHROOTM_EXEC="DEBUG=Y chroot_master.sh" || CHROOTM_EXEC="chroot_master.sh"

AW_RUN="$RUN ./alpha-wrap/alpha-wrap"
TEMP_DIR=./build.temp
ALPINE_SETUP_CMDLINE_FILE="./res/cmdline-alpine_setup.txt"

mkdir -p ${TEMP_DIR}

# Check for essential file
if [ ! -f "${ALPINE_SETUP_CMDLINE_FILE}" ]; then
  echo "File: ${ALPINE_SETUP_CMDLINE_FILE} has not been found"
  echo "It's essential for further operations, exiting"
  exit 1
fi

${AW_RUN} waitfor

# Function to create an edition
create_edition() {
    local edition=$1
    local chroot=$2
    local device=$3
    local size=$4
    local boot_dir="${TEMP_DIR}/${edition}_boot"
    local image="images/alpbase-${edition}-$(date +%m-%Y_d%d%H%M).iso"

    echo "Creating ${edition^} Edition"
    ${AW_RUN} extstore add "${image}" "$size"
    ${AW_RUN} command "/bin/ash -l -c '${CHROOTM_EXEC} exec ${chroot} alpbase_builder.sh ${edition} ${device}'"

    mount_and_sync "${device}1" "$boot_dir"
    compress_image "$image"
}

# Function to mount, sync, and unmount
mount_and_sync() {
    local device=$1
    local boot_dir=$2

    ${AW_RUN} command "/bin/ash -l -c 'mount ${device} /mnt'"
    mkdir -p "$boot_dir"
    ${AW_RUN} sync "${boot_dir}/" /mnt/vmlinuz-rpi -r
    ${AW_RUN} sync "${boot_dir}/" /mnt/initramfs-rpi -r
    ${AW_RUN} sync "${boot_dir}/" /mnt/cmdline.txt -r
    ${AW_RUN} command "/bin/ash -l -c 'umount /mnt'"
}

# Function to compress images in various formats
compress_image() {
    local image=$1

    gzip -c "$image" > "${image}.gz"
    bzip2 -c "$image" > "${image}.bz2"
    xz -c "$image" > "${image}.xz"
}

res=0
# Creating Editions
# Based on Alpine ARMHF
${AW_RUN} command "/bin/ash -l -c '${CHROOTM_EXEC} exec "chroot.armhf" alpbase_builder.sh updates'" || res=$?
if [ $res -ne 0 ]; then
  echo "No updates avaliable"
fi

create_edition "super_light" "chroot.armhf" "/dev/sda" "450MB"

# Based on Alpine AARCH64
${AW_RUN} command "/bin/ash -l -c '${CHROOTM_EXEC} exec "chroot.aarch64" alpbase_builder.sh updates'" || res=$?
if [ $res -ne 0 ]; then
  echo "No updates avaliable"
fi

create_edition "just_light" "chroot.aarch64" "/dev/sdb" "500MB"
create_edition "bedesktop" "chroot.aarch64" "/dev/sdc" "5200MB"

# Finalization and Testing
${AW_RUN} stop
#${AW_RUN} --device raspi3b "${TEMP_DIR}/sl_boot/vmlinuz-rpi" --imgboot n \
#          "${TEMP_DIR}/sl_boot/vmlinuz-rpi" "${TEMP_DIR}/sl_boot/initramfs-rpi" \
#          --cmdline "${ALPINE_SETUP_CMDLINE_FILE}"

exit 0
