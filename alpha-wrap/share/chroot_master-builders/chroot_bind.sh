#!/bin/bash

[ -n "$PRETEND" ] && [[ $(echo "$PRETEND" | tr '[:upper:]' '[:lower:]') =~ ^y|yes|1|on$ ]] && \
        RUN="echo" || RUN=

[ -n "$DEBUG" ] && [[ $(echo "$DEBUG" | tr '[:upper:]' '[:lower:]') =~ ^y|yes|1|on$ ]] && \
        set -xe || set -e


function print_help() {
  local indent_cnt=$(basename $0 | wc -c)
  local indent_p1=$(printf "%*s" "$indent_cnt" "")

  cat <<EOF
Usage:
$(basename $0) system <chroot dir.>
  Bind system directories: 'system' (/dev, /proc, /sys)

$(basename $0) dir <source dir.> <dest. dir.>
  Bind selected(source) directory.

$(basename $0) --unbind|-u system <chroot dir.>
  Unbind system directories.

$(basename $0) --unbind|-u <dest. dir>
  Unbind directory.

$(basename $0) help
  Print this help and exit.

EOF
}

function bind_system() {
  local ch_root="$1"
  local mnt_path

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

function unbind_system() {
  local ch_root="$1"
  local mnt_path

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

function bind_dir() {
  local ch_root="$1"
  local targets_dir="$2"

  mnt_path=$(realpath ${ch_root}/usr/local/bin)
  if [ $(mount | grep "${mnt_path}" | wc -l) -eq 0 ]; then
    $RUN mount --bind ${targets_dir} ${mnt_path}
  fi
}

function unbind_dir() {
  local ch_root="$1"

  mnt_path=$(realpath ${ch_root}/usr/local/bin)
  if [ $(mount | grep "${mnt_path}" | wc -l) -ne 0 ]; then
    $RUN umount ${mnt_path}
  fi
}

_MODE=bind

if [ "$1" == "-u" ] || [ "$1" == "--unbind" ]; then
  _MODE=unbind
  _COMMAND=$2
  _ARG1=$3
  _ARG2=$4
else
  _COMMAND=$1
  _ARG1=$2
  _ARG2=$3
fi

case ${_COMMAND} in
  system)
    ${_MODE}_system ${_ARG1}
  ;;
  dir)
    ${_MODE}_dir ${_ARG1} ${_ARG2}
  ;;
  help|--help|-h)
    print_help
  ;;
  *)
    echo "Missing parameter, 'help' for help"
    exit 1
  ;;
esac

exit 0
