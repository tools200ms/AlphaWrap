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


# Initialize an index variable to track the current device
DEVICE_INDEX=0
# Array of devices to cycle through
DEVICES=("/dev/sda" "/dev/sdb" "/dev/sdc" "/dev/sdd" "/dev/sde" "/dev/sdf" "/dev/sdg" "/dev/sdh")

ADD_TESTS=false

if [ "$1" == "addtests" ]; then
  ADD_TESTS=true
fi

# Define the function to return the next device
next_device() {
    # Update the index to the next device, looping back to 0 if we exceed the array length
    DEVICE_INDEX=$((DEVICE_INDEX + 1))
}

get_device() {
    echo "${DEVICES[$DEVICE_INDEX]}"
}

$RUN mkdir -p ${TEMP_DIR}

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
    local size=$3

    local device=
    local boot_dir="${TEMP_DIR}/${edition}_boot"
    local image="images/alpbase-${edition}-$(date +%m-%Y_d%d%H%M).iso"

    echo "Creating ${edition^} Edition"
    ${AW_RUN} extstore add "${image}" "$size"

    device=$(get_device)
    echo "    setup disk: ${device}"

    ${AW_RUN} command "/bin/ash -l -c '${CHROOTM_EXEC} exec ${chroot} alpbase_builder.sh ${edition} ${device}'"

    mount_and_sync "${device}1" "$boot_dir"
    compress_image "$image"
    next_device
}

# Function to mount, sync, and unmount
mount_and_sync() {
    local device=$1
    local boot_dir=$2

    ${AW_RUN} command "/bin/ash -l -c 'mount ${device} /mnt'"
    $RUN mkdir -p "$boot_dir"
    ${AW_RUN} sync "${boot_dir}/" /mnt/vmlinuz-rpi -r
    ${AW_RUN} sync "${boot_dir}/" /mnt/initramfs-rpi -r
    ${AW_RUN} sync "${boot_dir}/" /mnt/cmdline.txt -r

    # add tests:
    if $ADD_TESTS; then
      echo "Adding tests"
    fi

    ${AW_RUN} command "/bin/ash -l -c 'umount /mnt'"
}

# Function to compress images in various formats
compress_image() {
    local image=$1

    $RUN gzip -c "$image" > "${image}.gz"
    $RUN bzip2 -c "$image" > "${image}.bz2"
    $RUN xz -c "$image" > "${image}.xz"
}

res=0
# Creating Editions
# Based on Alpine ARMHF
${AW_RUN} command "/bin/ash -l -c '${CHROOTM_EXEC} exec "chroot.armhf" alpbase_builder.sh updates'" || res=$?
if [ $res -eq 0 ] || [ $(ls images/alpbase-super_light*.iso 2>/dev/null | wc -l) -eq 0 ]; then
  create_edition "super_light" "chroot.armhf" "450MB"
else
  echo "No updates available, or image already exists"
  echo "Skipping build"
fi

# Based on Alpine AARCH64
${AW_RUN} command "/bin/ash -l -c '${CHROOTM_EXEC} exec "chroot.aarch64" alpbase_builder.sh updates'" || res=$?
if [ $res -eq 0 ] || \
    [ $(ls images/alpbase-just_light*.iso 2>/dev/null | wc -l) -eq 0 ] || \
    [ $(ls images/alpbase-be_desktop*.iso 2>/dev/null | wc -l) -eq 0 ]; then
  create_edition "just_light" "chroot.aarch64" "500MB"
  create_edition "be_desktop" "chroot.aarch64" "5200MB"
else
  echo "No updates available, or image already exists"
  echo "Skipping build"
fi

# Finalization and Testing
# ${AW_RUN} stop

exit 0
