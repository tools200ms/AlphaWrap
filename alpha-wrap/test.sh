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



exit 0
