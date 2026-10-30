#!/bin/bash
# Standalone hook for certificate renewal and container service operations.
set -e
current_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
. "${current_dir}/options.conf"
. "${current_dir}/include/service.sh"
. "${current_dir}/include/check_dir.sh" || :
[ "$#" = 2 ] || { echo "Usage: $0 {start|stop|restart|reload|status|enable|disable} SERVICE" >&2; exit 1; }
service "$2" "$1"
