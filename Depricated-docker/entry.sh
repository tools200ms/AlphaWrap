#!/bin/sh
set -e

mkdir -p /root/iso

[ -d /iso ] && \
        dev2fs -s /iso /root/iso -o allow_other ||
        echo "Please share local 'iso' with '/iso' directory"


sleep infinity
