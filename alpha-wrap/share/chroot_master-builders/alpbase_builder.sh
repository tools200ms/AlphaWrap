
#!/bin/bash -l
# Based on: https://wiki.alpinelinux.org/wiki/Alpine_Linux_in_a_chroot

if [ -n "$PRETEND" ] && [[ $(echo "$PRETEND" | tr '[:upper:]' '[:lower:]') =~ ^y|yes|1|on$ ]]; then
  RUN="echo"
else
  RUN=
fi

[ -n "$DEBUG" ] && [[ $(echo "$DEBUG" | tr '[:upper:]' '[:lower:]') =~ ^y|yes|1|on$ ]] && \
        set -xe -o pipefail || set -e -o pipefail

# Add flag variable
MPY_INIT=false

function print_help() {
  local indent_cnt=$(basename $0 | wc -c)
  local indent_p1=$(printf "%*s" "$indent_cnt" "")

  cat <<EOF
Usage:
$(basename $0) [-m|--mpyinit] super_light | sl    <device>
${indent_p1}[-m|--mpyinit] just_light  | jl    <device>
${indent_p1}[-m|--mpyinit] be_desktop  | bd    <device>

  AlpBase edition for installation: Super Light, Just Light, BeDesktop
  <device> - block device for installation of a selected edition

  Options:
    -m, --mpyinit    Initialize micropython support

$(basename $0) updates|u
  Check if Alpine updates are available. If so, updates are installed
  and '0' is returned. Otherwise, 'non-zero' exit code is returned.

$(basename $0) help
  Print this help and exit.

EOF
}

# ... [rest of the functions remain unchanged until MODE parsing] ...

# Parse flags before MODE
while [[ $1 == -* ]]; do
    case "$1" in
        -m|--mpyinit)
            MPY_INIT=true
            shift
            ;;
        *)
            break
            ;;
    esac
done

MODE=$1
SETUP_DEV=$2

# ... [rest of the code remains unchanged until the micropython section] ...

# MPY_INIT: Add experimental mpy_init:
if [ "$MPY_INIT" = true ]; then
    chroot ${SETUP_ROOT} apk add micropython
fi
# ... [rest of the file remains unchanged] ...