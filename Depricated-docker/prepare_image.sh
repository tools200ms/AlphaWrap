#!/bin/bash

[ -n "$DEBUG" ] && [[ $(echo "$DEBUG" | tr '[:upper:]' '[:lower:]') =~ ^y|yes|1|on$ ]] && \
        set -xe || set -e

[ -n "$PRETEND" ] && [[ $(echo "$PRETEND" | tr '[:upper:]' '[:lower:]') =~ ^y|yes|1|on$ ]] && \
        RUN="echo" || RUN=

# : ${MIRRORS_URL:=https://mirrors.alpinelinux.org/mirrors.txt}
ALP_MIRROR="http://eu.edge.kernel.org/alpine"

ALP_VER=3.20
ALP_VER_SUB=1
ALP_VER_FULL=${ALP_VER}.${ALP_VER_SUB}

# 32bit ARM:
#ALP_ARCH=armhf
# 64bit ARM:
ALP_ARCH=aarch64

ALP_VARIANT=rpi

TAR_FILE=alpine-${ALP_VARIANT}-${ALP_VER_FULL}-${ALP_ARCH}.tar.gz
ISO_ROOT=/iso
#ISO_ROOT=/root/iso

echo_first_arg() {
  echo $1
}


if [ ! -e $ISO_ROOT/$TAR_FILE ] ; then
    wget https://dl-cdn.alpinelinux.org/alpine/v${ALP_VER}/releases/aarch64/${TAR_FILE} \
        -O $ISO_ROOT/$TAR_FILE
elif [ ! -f $ISO_ROOT/$TAR_FILE ] ; then
    echo "Something wrong with a file: $ISO_ROOT/$TAR_FILE"
    exit 1
fi

if [ -d $ISO_ROOT/build ] ; then
    # rm build directory, for fresh start
    rm -rf $ISO_ROOT/build
elif [ -e $ISO_ROOT/build ] ; then
    echo "'$ISO_ROOT/build' should be a directory"
    exit 1
fi

mkdir $ISO_ROOT/build

# unpack
tar -xzvf $ISO_ROOT/$TAR_FILE -C $ISO_ROOT/build

# add specific overlay:


# calculate image size
DU_M=$(echo_first_arg $(du -sm --apparent-size $ISO_ROOT/build))
DU_BOOT_M=$(echo_first_arg $(du -sm --apparent-size $ISO_ROOT/build/boot))

SYS_SIZE_MARGIN_M=450
BOOT_SIZE_X=2

# add size margin
MB_SYS_SIZE=$(($DU_M - $DU_BOOT_M + $SYS_SIZE_MARGIN_M))
MB_BOOT_SIZE=$(( (($DU_BOOT_M * $BOOT_SIZE_X) / 8) * 8 ))
MB_SIZE=$(($MB_SYS_SIZE + $MB_BOOT_SIZE))

# validate if 'MB_SIZE' holds OK data
if [ $MB_SIZE -gt 400 ] && [ $MB_SIZE -lt 20 ] ; then
    echo "Too large size ..."
    exit 1
fi

echo "Entire SIZE: $MB_SIZE"
echo "BOOT SIZE: $MB_BOOT_SIZE"

# create image, and partition table
dd if=/dev/zero of=$ISO_ROOT/image.iso bs=1048576 count=$MB_SIZE

# 128 * 8192 is one MB
SYS_BEGIN_SECTOR=$(($MB_BOOT_SIZE * 2048))

fdisk $ISO_ROOT/image.iso <<EOF
o
n
p
1
2048
$(($SYS_BEGIN_SECTOR - 1))
t
c
n
p
2
$SYS_BEGIN_SECTOR

a
1

w
EOF

create_loopdev() {
  loop_dev=$1

  if [ -e $loop_dev ]; then
    # Loop Device exists
    return
  fi

  # create loop device
  loop_minor="${loop_dev##*loop}"

  mknod $loop_dev b 7 $loop_minor
  # ensure permissions are correct:
  chown root:disk $loop_dev
  chmod 660 $loop_dev

  return
}

mkdir -p /mnt/dist/boot /mnt/dist/root

partprobe

#curl -LOs \
#  ${ALP_MIRROR}/v${ALP_VER}/main/${ALP_ARCH}/apk-tools-static-2.14.4-r0.apk
#tar -xzf apk-tools-static-*.apk

# Get avaliable loop device, normally '/dev/loop0'
LOBOOT_DEV=$(echo_first_arg $(losetup -f))
create_loopdev $LOBOOT_DEV
# Create device for mounting partition that will be used as 'boot'
losetup --offset $((2048*512)) $LOBOOT_DEV $ISO_ROOT/image.iso

# Get next avaliable loop device, normally '/dev/loop1'
LOROOT_DEV=$(echo_first_arg $(losetup -f))
create_loopdev $LOROOT_DEV
# Create device for mounting partition that will be used as 'root'
losetup --offset $(($SYS_BEGIN_SECTOR * 512)) $LOROOT_DEV $ISO_ROOT/image.iso


mkfs.vfat -n BOOT -F 32 $LOBOOT_DEV
mkfs.ext4 -L SYS  $LOROOT_DEV


mount $LOBOOT_DEV /mnt/dist/boot
mount $LOROOT_DEV /mnt/dist/root

# install files:
cp -r $ISO_ROOT/boot/* /mnt/dist/boot/
#rsync -a --exclude 'apks' --exclude '.alpine-release' \
#      $ISO_ROOT/build/ /mnt/dist/boot/
#rsync -a \
#      $ISO_ROOT/build/boot /mnt/dist/boot/

ROOT_BLK_UUID=$(blkid -s UUID -o value $LOROOT_DEV)

eval "echo $(cat /system/cmdline.txt)" > /mnt/dist/boot/cmdline.txt

#for pkg in $(find $ISO_ROOT/build/apks | grep -e '\.apk$'); do tar -xzf "$pkg" -C /mnt/dist/root/; done
tar -xvf /iso/org.alp.tar -C /mnt/dist/root/

clean_mounts() {
  # Umount
  umount /mnt/dist/boot
  umount /mnt/dist/root
  losetup -d $LOBOOT_DEV
  losetup -d $LOROOT_DEV
}

# RTC setup
# add: 
# /boot/usercfg.txt <<
# dtparam=i2c_arm=on
# dtoverlay=i2c-rtc,param=pcf8563
# EOF

echo "DONE, Alpine ISO prepared"

exit 0
