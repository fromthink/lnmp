#!/bin/bash

# Minimal upstream backports announced on 2026-10-21:
# https://www.php.net/archive/2026.php#2026-10-21-5
# Run in the extracted PHP source directory, before configure/make.
Apply_PHP_Security_Patch() {
  local php_version="$1" patch_file patch_url
  case "${php_version}" in
    7.4.33|8.0.30|8.1.34) ;;
    7.4.*|8.0.*|8.1.*)
      echo "${CFAILURE}Security backports require PHP 7.4.33, 8.0.30 or 8.1.34; refusing ${php_version}.${CEND}"
      return 1
      ;;
    *) return 0 ;;
  esac

  patch_file="${current_dir}/src/php-${php_version}-CVE-2026-109618-109619.patch"
  patch_url="https://github.com/php/php-src/compare/php-${php_version}...PHP-${php_version%.*}-CVE-2026-109618-109619.diff"
  if [ ! -s "${patch_file}" ]; then
    # Use certificate verification and an atomic rename; never cache partial downloads.
    if ! wget --tries=3 --timeout=30 -O "${patch_file}.tmp" "${patch_url}"; then
      rm -f "${patch_file}.tmp"
      echo "${CFAILURE}Cannot download PHP security backport: ${patch_url}${CEND}"
      return 1
    fi
    if ! grep -q '^diff --git ' "${patch_file}.tmp"; then
      rm -f "${patch_file}.tmp"
      echo "${CFAILURE}Invalid or empty PHP security backport.${CEND}"
      return 1
    fi
    mv "${patch_file}.tmp" "${patch_file}" || return 1
  fi

  if patch --batch --forward --fuzz=0 --dry-run -p1 < "${patch_file}"; then
    patch --batch --forward --fuzz=0 -p1 < "${patch_file}" || return 1
  elif patch --batch --reverse --fuzz=0 --dry-run -p1 < "${patch_file}"; then
    echo "PHP security backport already applied."
  else
    echo "${CFAILURE}PHP security backport does not match this source; stopping.${CEND}"
    return 1
  fi
}
