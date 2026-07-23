#!/bin/bash
source /opt/conda/etc/profile.d/conda.sh

if [ -f /opt/cp2k_toolchain/install/setup ]; then
    source /opt/cp2k_toolchain/install/setup
fi

export PATH="/opt/cp2k/bin:$PATH"

if [ $# -eq 0 ]; then
    /bin/bash
else
    exec "$@"
fi
