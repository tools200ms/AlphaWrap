#!/bin/sh

DEVICE=/dev/sda
CHROOT=/mnt/dist

# add squid:
 # Uncomment and adjust the following to add a disk cache directory.
#75 cache_dir aufs /var/cache/squid 12800 32 256
#76 maximum_object_size 45056 KB
#77 minimum_object_size 0

# Alpine Installation:


sensors-detect
No i2c device files found.
but sensors work

# lm_sensors does not exists
# rc-update add lm_sensors default
# rc-update add sensord default

remove debugfs
cat /boot/config-6.6.49-0-rpi | grep DEBUG | grep -v -e ^\#


# default rc-update:
acpid - sysinit
chronyd - default (OK)
crond - sysinit
hwdrivers - sysinit
mdev - sysinit
networking - boot
seedrng - boot




# at boot time

exit

# end of chroot operations
umount $CHROOT
sync
