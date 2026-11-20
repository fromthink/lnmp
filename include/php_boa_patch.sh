#!/bin/bash

# BOA 5.x-dev snapshot; patch order follows BOA's php-sec series.
Apply_PHP_BOA_Patches() {
  local php_version="$1" version name digest patch_file url stage status=0
  local commit=204a27bb43e05e0c071e4e8c78cc11eb2586ae9f
  local manifest="${current_dir}/include/php_boa_patches.txt"
  local -a patches=()
  while read -r version name digest; do
    [ "$version" = "$php_version" ] || continue
    patch_file="${current_dir}/src/boa-${name}"
    if [ ! -s "$patch_file" ]; then
      url="https://raw.githubusercontent.com/omega8cc/boa/${commit}/aegir/patches/php-sec/${name}"
      if ! wget --tries=3 --timeout=30 -O "${patch_file}.tmp" "$url"; then
        rm -f "${patch_file}.tmp"
        return 1
      fi
      if ! printf '%s  %s\n' "$digest" "${patch_file}.tmp" | sha256sum -c -; then
        rm -f "${patch_file}.tmp"
        return 1
      fi
      mv "${patch_file}.tmp" "$patch_file" || return 1
    fi
    printf '%s  %s\n' "$digest" "$patch_file" | sha256sum -c - || return 1
    patches+=("$patch_file")
  done < "$manifest"
  [ "${#patches[@]}" -gt 0 ] || return 1

  # Later patches overlap earlier ones. Validate the entire sequence on a copy
  # before touching the build tree; reverse the whole sequence to detect reruns.
  stage=$(mktemp -d) || return 1
  # Only patch targets are needed for context validation, not a second full tree.
  awk '/^(--- a\/|\+\+\+ b\/)/ { path=$2; sub(/^[ab]\//, "", path); print path }' "${patches[@]}" | sort -u > "${stage}/targets"
  while IFS= read -r name; do
    [ ! -f "$name" ] || printf '%s\n' "$name"
  done < "${stage}/targets" > "${stage}/files"
  if ! tar -cf "${stage}/source.tar" -T "${stage}/files" ||
     ! mkdir "${stage}/source" ||
     ! tar -xf "${stage}/source.tar" -C "${stage}/source"; then
    rm -rf "$stage"
    return 1
  fi
  for patch_file in "${patches[@]}"; do
    if patch --batch --forward --fuzz=0 --dry-run -d "${stage}/source" -p1 < "$patch_file" >> "${stage}/check.log" 2>&1; then
      patch --batch --forward --fuzz=0 -d "${stage}/source" -p1 < "$patch_file" >> "${stage}/check.log" 2>&1 || { status=1; break; }
    elif ! patch --force --reverse --fuzz=0 --dry-run -d "${stage}/source" -p1 < "$patch_file" >> "${stage}/check.log" 2>&1; then
      status=1
      break
    fi
  done
  if [ "$status" -ne 0 ]; then
    rm -rf "${stage}/source"
    if ! mkdir "${stage}/source" || ! tar -xf "${stage}/source.tar" -C "${stage}/source"; then
      rm -rf "$stage"
      return 1
    fi
    status=0
    local index
    for ((index=${#patches[@]}-1; index>=0; index--)); do
      if ! patch --force --reverse --fuzz=0 -d "${stage}/source" -p1 < "${patches[index]}" >> "${stage}/check.log" 2>&1; then
        status=1
        break
      fi
    done
    if [ "$status" -eq 0 ]; then
      echo "BOA PHP security patch series already applied."
    else
      cat "${stage}/check.log"
      echo "${CFAILURE}BOA PHP security patches do not match this source; stopping.${CEND}"
    fi
    rm -rf "$stage"
    return "$status"
  fi
  rm -rf "$stage"

  for patch_file in "${patches[@]}"; do
    if patch --batch --forward --fuzz=0 --dry-run -p1 < "$patch_file"; then
      patch --batch --forward --fuzz=0 -p1 < "$patch_file" || return 1
    elif ! patch --force --reverse --fuzz=0 --dry-run -p1 < "$patch_file"; then
      return 1
    fi
  done
}
