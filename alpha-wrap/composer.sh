#!/bin/sh

[ -n "$PRETEND" ] && [[ $(echo "$PRETEND" | tr '[:upper:]' '[:lower:]') =~ ^y|yes|1|on$ ]] && \
        RUN="echo" || RUN=

if [ -n "$DEBUG" ] && [[ $(echo "$DEBUG" | tr '[:upper:]' '[:lower:]') =~ ^y|yes|1|on$ ]]; then
  set -xe
  CHROOTM_EXEC="DEBUG=Y chroot_master.sh"
else
  set -e
  CHROOTM_EXEC="chroot_master.sh"
fi

AW_RUN="$RUN ./alpha-wrap/alpha-wrap"
TEMP_DIR=./build.temp

mkdir -p ${TEMP_DIR}

ALPINE_SETUP_CMDLINE_FILE="./res/cmdline-alpine_setup.txt"

if [ ! -f "${ALPINE_SETUP_CMDLINE_FILE}" ]; then
  echo "File: ${ALPINE_SETUP_CMDLINE_FILE} has not been found"
  echo "It's essential for a further operations, exiting"
  return 1
fi

${AW_RUN} waitfor

# Build Editions:

echo "Creating Super Light Edition"
BUILD_DATE=$(date +%m-%Y_d%d%H%M)
IMAGE_SL=images/alpbase-super_light-${BUILD_DATE}.iso

${AW_RUN} extstore add ${IMAGE_SL} 450MB
${AW_RUN} command "/bin/ash -l -c '${CHROOTM_EXEC} exec chroot.armhf alpbase_builder.sh sl /dev/sda'"

${AW_RUN} command "/bin/ash -l -c 'mount /dev/sda1 /mnt'"
mkdir -p ${TEMP_DIR}/sl_boot
${AW_RUN} sync ${TEMP_DIR}/sl_boot/ /mnt/vmlinuz-rpi -r
${AW_RUN} sync ${TEMP_DIR}/sl_boot/ /mnt/initramfs-rpi -r
${AW_RUN} sync ${TEMP_DIR}/sl_boot/ /mnt/cmdline.txt -r
${AW_RUN} command "/bin/ash -l -c 'umount /mnt'"

# test
${AW_RUN} stop

${AW_RUN} --device raspi3b ${IMAGE_SL} \
          --imgboot n ${TEMP_DIR}/sl_boot/vmlinuz-rpi ${TEMP_DIR}/sl_boot/initramfs-rpi \
          --cmdline ${ALPINE_SETUP_CMDLINE_FILE}

exit 0

gzip -c ${IMAGE_SL} > ${IMAGE_SL}.gz
bzip2 -c ${IMAGE_SL} > ${IMAGE_SL}.bz2
xz -c ${IMAGE_SL} > ${IMAGE_SL}.xz


echo "Creating Just Light Edition"
BUILD_DATE=$(date +%m-%Y_d%d%H%M)
IMAGE_JL=images/alpbase-just_light-${BUILD_DATE}.iso

${AW_RUN} extstore add ${IMAGE_JL} 500MB
${AW_RUN} command "/bin/ash -l -c '${CHROOTM_EXEC} exec chroot.aarch64 alpbase_builder.sh jl /dev/sdb'"

${AW_RUN} command "/bin/ash -l -c 'mount /dev/sdb1 /mnt'"
mkdir -p ${TEMP_DIR}/jl_boot
${AW_RUN} sync ${TEMP_DIR}/jl_boot/ /mnt/vmlinuz-rpi -r
${AW_RUN} sync ${TEMP_DIR}/jl_boot/ /mnt/initramfs-rpi -r
${AW_RUN} sync ${TEMP_DIR}/jl_boot/ /mnt/cmdline.txt -r
${AW_RUN} command "/bin/ash -l -c 'umount /mnt'"

# test


# ${AW_RUN} --device raspi3b ${IMAGE} --imgboot y vmlinuz-rpi initramfs-rpi
gzip -c ${IMAGE_JL} > ${IMAGE_JL}.gz
bzip2 -c ${IMAGE_JL} > ${IMAGE_JL}.bz2
xz -c ${IMAGE_JL} > ${IMAGE_JL}.xz

echo "Creating BeDesktop Edition"

BUILD_DATE=$(date +%m-%Y_d%d%H%M)
IMAGE_BD=images/alpbase-bedesktop-${BUILD_DATE}.iso

${AW_RUN} extstore add ${IMAGE_BD} 5200MB
${AW_RUN} command "/bin/ash -l -c '${CHROOTM_EXEC} exec chroot.aarch64 alpbase_builder.sh bd /dev/sdc'"

${AW_RUN} command "/bin/ash -l -c 'mount /dev/sdc1 /mnt'"
mkdir -p ${TEMP_DIR}/bd_boot
${AW_RUN} sync ${TEMP_DIR}/bd_boot/ /mnt/vmlinuz-rpi -r
${AW_RUN} sync ${TEMP_DIR}/bd_boot/ /mnt/initramfs-rpi -r
${AW_RUN} sync ${TEMP_DIR}/bd_boot/ /mnt/cmdline.txt -r
${AW_RUN} command "/bin/ash -l -c 'umount /mnt'"

# Do Tests

# Pack
gzip -c ${IMAGE_BD} > ${IMAGE_BD}.gz
bzip2 -c ${IMAGE_BD} > ${IMAGE_BD}.bz2
xz -c ${IMAGE_BD} > ${IMAGE_BD}.xz


${AW_RUN} stop

# Do tests:
#${AW_RUN} -d raspi3b ${IMAGE_JL} -i y vmlinuz-rpi initramfs-rpi

# rm -rf ${TEMP_DIR}

exit 0
