#!/bin/bash
# Based on: https://wiki.alpinelinux.org/wiki/Alpine_Linux_in_a_chroot

[ -n "$PRETEND" ] && [[ $(echo "$PRETEND" | tr '[:upper:]' '[:lower:]') =~ ^y|yes|1|on$ ]] && \
        RUN="echo" || RUN=

[ -n "$DEBUG" ] && [[ $(echo "$DEBUG" | tr '[:upper:]' '[:lower:]') =~ ^y|yes|1|on$ ]] && \
        set -xe || set -e

readonly VERSION="0.0.2"
readonly mirror="http://quantum-mirror.hu/mirrors/pub/alpine"
# https://dl-cdn.alpinelinux.org/alpine/edge
#"http://alpine.sakamoto.pl/alpine"

# Chroot directories for Alpine ARMHF (32-bit) and AARCH64 (64-bit)
readonly build_dir=("chroot.armhf" "chroot.aarch64")

if [ -n "$RUN" ]; then
  echo "PRETEND mode is 'ON', just showing what would be done."
fi


function print_help() {
    cat <<EOF
Usage:
$(basename $0) make
  - create chroots

$(basename $0) enter <chroot.armhf|chroot.aarch64>
  - enter selected chroot

$(basename $0) exec <chroot.armhf|chroot.aarch64> "command"
  - execute command in selected chroot

$(basename $0) close
  - close (unmount) resources used by chroots

$(basename $0) -v|--version
  - show version and credentials

EOF
}

function print_version() {
  cat <<EOF
$(basename $0) - AlphaWraper - ARM VM management tool
Version:
  ${VERSION}
by:
  Mateusz Piwek

EOF
}

# Install chroot
function deploy() {
  local ch_root="$1"
  local arch=$2

  if [ -z $RUN ]; then
    temp_dir=$(mktemp -d)
  else
    temp_dir=$(mktemp -du)
  fi

  branch=$(curl -s ${mirror}/ | sed -n 's/.*href="\(.*\)".*/\1/p' | grep -e "v[0-9]\.[0-9][0-9]" | sort -V | tail -n 1)
  branch=$(basename ${branch})

  apk_tools_url=$(curl -s ${mirror}/${branch}/main/${arch}/ | \
                  sed -n 's/.*href="\(.*\)".*/\1/p' | grep -e "apk-tools-static-.*.apk")
  apk_tools_url=$(basename "$apk_tools_url")

  $RUN curl -sL ${mirror}/${branch}/main/${arch}/${apk_tools_url} \
            -o ${temp_dir}/apk-tools-static.apk
  $RUN tar -xzf ${temp_dir}/apk-tools-static.apk -C $ch_root
  $RUN rm $temp_dir/apk-tools-static.apk
  $RUN rmdir $temp_dir

  $RUN ./${ch_root}/sbin/apk.static -X ${mirror}/${branch}/main -U --allow-untrusted -p ${ch_root} --initdb add alpine-base

  # Basic configuration
  if [ -z $RUN ]; then
    echo -e 'nameserver 8.8.8.8\nnameserver 2620:0:ccc::2' > ${ch_root}/etc/resolv.conf
    mkdir -p ${ch_root}/etc/apk
    echo "${mirror}/${branch}/main" > ${ch_root}/etc/apk/repositories
    echo "${mirror}/${branch}/community" >> ${ch_root}/etc/apk/repositories
  else
    echo "Pretending that working hard on a basic system configuration ..."
    sleep 1 # o-<-<
  fi
}

function bind_with_host() {
  ch_root="$1"

  mnt_path=$(realpath ${ch_root}/dev)
  if [ $(mount | grep "$mnt_path" | wc -l) -eq 0 ]; then
    $RUN mount -o bind /dev ${mnt_path}
  fi

  mnt_path=$(realpath ${ch_root}/proc)
  if [ $(mount | grep "$mnt_path" | wc -l) -eq 0 ]; then
    $RUN mount -t proc none ${mnt_path}
  fi

  mnt_path=$(realpath ${ch_root}/sys)
  if [ $(mount | grep "$mnt_path" | wc -l) -eq 0 ]; then
    $RUN mount -o bind /sys ${mnt_path}
  fi
}

function unbind_from_host() {
  ch_root="$1"

  mnt_path=$(realpath ${ch_root}/dev)
  if [ $(mount | grep "$mnt_path" | wc -l) -ne 0 ]; then
    $RUN umount ${mnt_path}
  fi

  mnt_path=$(realpath ${ch_root}/proc)
  if [ $(mount | grep "$mnt_path" | wc -l) -ne 0 ]; then
    $RUN umount ${mnt_path}
  fi

  mnt_path=$(realpath ${ch_root}/sys)
  if [ $(mount | grep "$mnt_path" | wc -l) -ne 0 ]; then
    $RUN umount ${mnt_path}
  fi
}

function bind_scripts() {
  ch_root="$1"
  targets_dir="$2"

  mnt_path=$(realpath ${ch_root}/usr/local/bin)
  if [ $(mount | grep "${mnt_path}" | wc -l) -eq 0 ]; then
    $RUN mount --bind ${targets_dir} ${mnt_path}
  fi
}

function unbind_scripts() {
  ch_root="$1"

  mnt_path=$(realpath ${ch_root}/usr/local/bin)
  if [ $(mount | grep "${mnt_path}" | wc -l) -ne 0 ]; then
    $RUN umount ${mnt_path}
  fi
}


function set_base() {
  targets_dir=$(dirname $(realpath $0))/chroot_master-builders
#  targets_dir=$(realpath ./targets)

  # deploy chrooted environment, and bind special file systems:

  for b_dir in ${build_dir[@]}; do
    arch=$(echo $b_dir | cut -d'.' -f2)

    # if exists assume chrooted environment is stetup
    if [ ! -f "${b_dir}/etc/alpine-release" ]; then
      mkdir -p $b_dir
      deploy $b_dir $arch
    fi

    bind_with_host ${b_dir}
    bind_scripts ${b_dir} ${targets_dir}
  done


  # perform image preparation:
  for b_dir in ${build_dir[@]}; do
    if [ -f ${b_dir}/etc/profile.d/50-chroot_env.sh ]; then
      continue
    fi

    arch=$(echo $b_dir | cut -d'.' -f2)

    # post deploy
    cat <<EOF > ${b_dir}/etc/profile.d/50-chroot_env.sh
TARGET_ARCH=$arch
EOF

    chroot ${b_dir} /bin/ash -c "apk update && apk upgrade && apk add bash blkid"
  done
}

function unset_base() {

  for b_dir in ${build_dir[@]}; do
    unbind_from_host ${b_dir}
    unbind_scripts ${b_dir}
  done
}

function check_param_chroot() {
  local dir_name=$(basename $1)

  if [ "${dir_name}" == "." ] || [[ ! " ${build_dir[@]} " =~ " ${dir_name} " ]]; then
    echo "Provide chroot name: ${build_dir[@]}"
    return 2
  fi

  # check if it's proper chroot ...

  return 0
}

res=0

case $1 in
  make)
    # bind
    # deploy
    # post deploy
    set_base
  ;;

  enter)
    check_param_chroot $2
    # bind
    # check
    set_base

    chroot $2 /bin/ash -l
  ;;

  exec)
    chroot_dir=$2
    command=$3

    check_param_chroot ${chroot_dir}
    # bind
    # check
    set_base

    shift 3
    chroot ${chroot_dir} ${command} "$@" || res=$?
  ;;

  close)
    unset_base
  ;;

  purge)

  ;;

  help|-h|--help)
    print_help
  ;;

  -v|--version)
    print_version
  ;;
esac

exit $res
