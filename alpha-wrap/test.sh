#!/bin/bash

[ -n "$PRETEND" ] && [[ $(echo "$PRETEND" | tr '[:upper:]' '[:lower:]') =~ ^y|yes|1|on$ ]] && \
        RUN="echo" || RUN=

[ -n "$DEBUG" ] && [[ $(echo "$DEBUG" | tr '[:upper:]' '[:lower:]') =~ ^y|yes|1|on$ ]] && \
        set -xe || set -e


function include_all() {
  readonly SCRIPT_PATH=$1
  readonly SCRIPT_BASE=$(basename $1)
  readonly SCRIPT_DIR=$(dirname $1)

  for script in $(ls ${SCRIPT_DIR}/${SCRIPT_BASE}-* 2>/dev/null); do
    if [ -x $script ]; then
      source $script
    fi
  done
}

export RUN
export DEBUG

TEST_ARGS1="-n -e test 'quated 1'"
export ARGS="$TEST_ARGS1"

readonly TEST_SCRIPT_BASE=$(echo "$0" | sed 's/test.sh$/alpha-wrap/')
include_all $TEST_SCRIPT_BASE


cnt=1
while [ -n "$ARGS" ]; do
  CARG=$(first_arg ${ARGS})
  printf "${cnt}: First arg: '%s'\n" "${CARG}"
  ARGS=$(last_args ${ARGS})
  printf "${cnt}: Last args: '%s'\n" "${ARGS}"
  cnt=$(($cnt+1))
done

validate_cmdline "root=UUID=864796f0-12e6-4dd7-92bb-272cad8beb7f modules=sd-mod,usb-storage,ext4 quiet rootfstype=ext4" && res=0 || res=$?

if [ $res -ne 0 ]; then
  echo "cmdline validation failed"
else
  echo "cmdline validation OK"
fi

validate_cmdline "BOOT_IMAGE=/vmlinuz-5.4.0 root=/dev/sda1 ro quiet splash" && res=0 || res=$?

if [ $res -ne 0 ]; then
  echo "cmdline validation failed"
else
  echo "cmdline validation OK"
fi

validate_cmdline "    " && res=0 || res=$?
if [ $res -ne 0 ]; then
  echo "cmdline validation failed"
else
  echo "cmdline validation OK"
fi

validate_cmdline "ddd" && res=0 || res=$?
if [ $res -ne 0 ]; then
  echo "cmdline validation failed"
else
  echo "cmdline validation OK"
fi


exit 0
