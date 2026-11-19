#!/bin/bash
set -euo pipefail
CMSG= CEND= CFAILURE=
cd "$(dirname "$0")/.."
. ./versions.txt
. ./include/download.sh
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
cd "$work"
archive="php-${php85_ver}.tar.gz"
printf 'fixture\n' > "$archive"
# The actual release digest must reject a corrupt cached download.
if (src_url="https://www.php.net/distributions/$archive"; Download_src); then
  echo "FAIL: corrupt cached archive accepted"
  exit 1
fi
# Exercise the success path using a known fixture digest.
php85_sha256=$(sha256sum "$archive")
php85_sha256=${php85_sha256%% *}
Verify_PHP_Archive "$archive"
src_url="https://www.php.net/distributions/$archive"
Download_src
php85_sha256=
if Verify_PHP_Archive "$archive"; then
  echo "FAIL: missing checksum accepted"
  exit 1
fi
php85_sha256=invalid
if Verify_PHP_Archive "$archive"; then
  echo "FAIL: malformed checksum accepted"
  exit 1
fi
# Other packages keep their existing download behavior.
printf 'fixture\n' > other.tar.gz
src_url=https://example.invalid/other.tar.gz
Download_src
echo 'PASS: corrupt cache rejected; valid cache accepted; missing/malformed digest rejected; other downloads preserved'
