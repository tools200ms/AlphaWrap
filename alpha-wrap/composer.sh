#!/bin/bash

# Function to check flags for pretend or debug mode
check_flag() {
    [ -n "$1" ] && echo "$1" | tr '[:upper:]' '[:lower:]' | grep -Eq '^y|yes|1|on$'
}

# Set RUN and CHROOTM_EXEC based on flags
[ "$(check_flag "$PRETEND")" ] && RUN="echo" || RUN=""

if [ "$(check_flag "$DEBUG")" ]; then
  set -xe
  CHROOTM_EXEC="DEBUG=Y chroot_master.sh"
else
  set -e
  CHROOTM_EXEC="chroot_master.sh"
fi

AW_RUN="$RUN ./alpha-wrap/alpha-wrap"
TEMP_DIR=./build.temp
ALPINE_SETUP_CMDLINE_FILE="./res/cmdline-alpine_setup.txt"

UPDATE_CHECK_AVAILABILITY_VM_CHROOT_CMD="alpbase_builder.sh updates"

# Initialize an index variable to track the current device
DEVICE_INDEX=0
# Array of devices to cycle through
DEVICES=("/dev/sda" "/dev/sdb" "/dev/sdc" "/dev/sdd" "/dev/sde" "/dev/sdf" "/dev/sdg" "/dev/sdh")

ADD_TESTS=false

# Define the function to return the next device
next_device() {
    # Update the index to the next device, looping back to 0 if we exceed the array length
    DEVICE_INDEX=$((DEVICE_INDEX + 1))
}

get_device() {
    echo "${DEVICES[$DEVICE_INDEX]}"
}

$RUN mkdir -p ${TEMP_DIR}/_test

if [ "$1" == "addtests" ]; then
  ADD_TESTS=true

  if [ ! -f ${TEMP_DIR}/_test/test_key ]; then
    ssh-keygen -t ed25519 -C "test@alpbase.200ms.net" -N "" -f ${TEMP_DIR}/_test/test_key
  fi
elif [ ! -z $1 ]; then
  echo "Unknown command: $1, the only commands are _none_ or 'addtests'"
  exit 2
fi


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

    if [ ! -d "$(dirname "$image")" ]; then
      echo "Attempted to create file: $image"
      echo "    but failed as no parent directory(ies) exists."
      echo "    Create appropriate directory(ies), so image file can be stored"
      echo ""
      return 2
    fi

    echo "Creating ${edition^} Edition"
    ${AW_RUN} extstore add "${image}" "$size"

    device=$(get_device)
    echo "    setup disk: ${device}"

    ${AW_RUN} command "/bin/ash -l -c '${CHROOTM_EXEC} exec ${chroot} alpbase_builder.sh ${edition} ${device}'"

    mount_and_sync "${device}1" "$boot_dir"
    compress_image "$image"

    # Get package list
    ${AW_RUN} sync -r ./images/ ${chroot}/var/log/alpbase_alpine-pkgs-${edition}.list
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
    if ${ADD_TESTS}; then
      echo "Adding tests"
      ${AW_RUN} command "/bin/ash -l -c 'touch /mnt/TESTING && mkdir -p /mnt/conf'"
      ${AW_RUN} sync "${TEMP_DIR}/_test/test_key.pub" "/mnt/conf/"
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
${AW_RUN} command "/bin/ash" "-l -c" ${CHROOTM_EXEC} exec "chroot.armhf" $UPDATE_CHECK_AVAILABILITY_VM_CHROOT_CMD || res=$?
if [ $res -eq 0 ] || [ $(ls images/alpbase-super_light*.iso 2>/dev/null | wc -l) -eq 0 ]; then
  create_edition "super_light" "chroot.armhf" "450MB"
else
  echo "No updates available, or image already exists"
  echo "Skipping build"
fi

# Based on Alpine AARCH64
${AW_RUN} command "/bin/ash" "-l -c" ${CHROOTM_EXEC} exec "chroot.aarch64" $UPDATE_CHECK_AVAILABILITY_VM_CHROOT_CMD || res=$?
if [ $res -eq 0 ] || [ $(ls images/alpbase-just_light*.iso 2>/dev/null | wc -l) -eq 0 ]; then
  create_edition "just_light" "chroot.aarch64" "500MB"
else
  echo "No updates available, or image already exists"
  echo "Skipping build"
fi

#if [ $res -eq 0 ] || [ $(ls images/alpbase-be_desktop*.iso 2>/dev/null | wc -l) -eq 0 ]; then
#  create_edition "be_desktop" "chroot.aarch64" "1500MB"
#else
#  echo "No updates available, or image already exists"
#  echo "Skipping build"
#fi


# Finalization and Testing
# ${AW_RUN} stop

exit 0
