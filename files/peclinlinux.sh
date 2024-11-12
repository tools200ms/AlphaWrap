#!/bin/sh

DEVICE=/dev/sda
CHROOT=/mnt/dist

#blkdiscard $DEVICE
#dd if=/dev/zero of=$DEVICE bs=4k

# Alpine Installation:
setup-alpine
1. hostname (user-setup)
2. password change (user-setup)
3. time-zone (user-setup)
4. setup mirror (user-setup)

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


chroot $CHROOT /bin/ash -l -c "/install"
# in chroot
setup-keymap EOF<<
us
us-intl
EOF

setup-timezone EOF<<
Europe/Warsaw
EOF

setup-hostname EOF<<
miniadmin
EOF

setup-user EOF<<
admin





EOF

# at boot time

exit

# end of chroot operations
umount $CHROOT
sync
