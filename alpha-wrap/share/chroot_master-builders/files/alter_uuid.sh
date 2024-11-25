#!/bin/bash

[ -n "$DEBUG" ] && [[ $(echo "$DEBUG" | tr '[:upper:]' '[:lower:]') =~ ^y|yes|1|on$ ]] && \
        set -xe || set -e

[ -n "$PRETEND" ] && [[ $(echo "$PRETEND" | tr '[:upper:]' '[:lower:]') =~ ^y|yes|1|on$ ]] && \
        RUN='echo' || RUN=


# Verify is file is a file device
part_dev=$(realpath $1)

part_type=$(lsblk -no fstype ${part_dev})
old_uuid=
new_uuid=
conf_uuid=


umount_part_by_dev() {
	if mount | grep -qe "^${1}"; then
		echo "Unmounting ${1}..."
		$RUN umount "${1}" 
		return $?
	fi
	
	return 0
}

remount_ro_part_by_dev() {
	# if options found part. mounted
	local options=$(mount | grep -e "^${1}" | awk '{print $NF}')
	local mnt_point=

	if [ -z "${options}" ]; then
		return 0
	fi

	if echo $options | tr '(' '_' | tr ',' '_' | tr ')' '_' | grep -qv _ro_; then
		mnt_point=$(findmnt -n -o TARGET ${1}) || return $?
		
		$RUN mount -o remount,ro ${mnt_point}
		return $?
	fi

	return 0
}

old_uuid=$(blkid | grep "$part_dev")

case $part_type in
	vfat)
		umount_part_by_dev ${part_dev}
		# Generate a random UUID for vfat (4 bytes in hex format, uppercase)
		new_uuid=$(printf "%08X" $(( RANDOM * RANDOM )))

		echo "Setting new UUID: $new_uuid for $part_dev"
		$RUN dosfslabel "$part_dev" "$new_uuid"
	;;
	ext4)
		remount_ro_part_by_dev ${part_dev}
		$RUN e2fsck -fp ${part_dev}
		$RUN tune2fs ${part_dev} -U random
		
	;;
esac

conf_uuid=$(blkid | grep "$part_dev")

echo $conf_uuid


sed -i.bak "s/${old_uuid}/${conf_uuid}/g" /mnt/etc/fstab
sed -i.bak "s/${old_uuid}/${conf_uuid}/g" /mnt/boot/cmdline.txt

exit 0
