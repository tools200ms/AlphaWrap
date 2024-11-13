#!/bin/sh

DEVICE=/dev/sda
CHROOT=/mnt/dist

# add squid:
 # Uncomment and adjust the following to add a disk cache directory.
#75 cache_dir aufs /var/cache/squid 12800 32 256
#76 maximum_object_size 45056 KB
#77 minimum_object_size 0

# Alpine Installation:
setup-alpine

3. network (default - post_setup)
4. proxy (default - post_setup)

5. ntp (OK)
6. user (ok)
7. ssh (OK)
8. disk (OK)

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
