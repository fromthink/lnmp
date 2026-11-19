#!/bin/bash
# Author:  yeho <lj2007331 AT gmail.com>
# BLOG:  https://linuxeye.com

# Official tar.gz SHA-256 values are pinned alongside versions in versions.txt.
Verify_PHP_Archive() {
  local archive="$1" expected
  case "${archive##*/}" in
    "php-${php82_ver}.tar.gz") expected=${php82_sha256} ;;
    "php-${php83_ver}.tar.gz") expected=${php83_sha256} ;;
    "php-${php84_ver}.tar.gz") expected=${php84_sha256} ;;
    "php-${php85_ver}.tar.gz") expected=${php85_sha256} ;;
    *) return 0 ;;
  esac
  if [[ ! "${expected}" =~ ^[a-f0-9]{64}$ ]] ||
     ! printf '%s  %s\n' "${expected}" "${archive}" | sha256sum -c -; then
    echo "${CFAILURE}PHP archive checksum verification failed: ${archive}${CEND}"
    return 1
  fi
}

Download_src() {
  [ -s "${src_url##*/}" ] && echo "[${CMSG}${src_url##*/}${CEND}] found" || { wget --limit-rate=100M --tries=6 -c --no-check-certificate ${src_url}; sleep 1; }
  if [ ! -e "${src_url##*/}" ]; then
    echo "${CFAILURE}Auto download failed! You can manually download ${src_url} into the src/ directory.${CEND}"
    kill -9 $$; exit 1;
  fi
  Verify_PHP_Archive "${src_url##*/}" || exit 1
}
