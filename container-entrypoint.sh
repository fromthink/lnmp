#!/bin/bash
set -e
if [ "$#" -gt 0 ]; then exec "$@"; fi
current_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
. "${current_dir}/options.conf"
. "${current_dir}/include/service.sh"
LNMP_Supervisor_Setup
# Foreground Supervisor receives Docker's termination signal as PID 1.
exec supervisord -n -c "${LNMP_SUPERVISOR_CONFIG}"
