#!/bin/bash
# Usage: bash tests/php-boa-patches.sh DIR
# DIR contains pristine php-{7.4.33,8.1.34}.tar.gz and the six BOA patches.
set -euo pipefail
CFAILURE= CEND=
repo=$(cd "$(dirname "$0")/.." && pwd)
fixtures=$(cd "${1:?Supply a directory containing source archives and BOA patches}" && pwd)
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
mkdir -p "$work/include" "$work/src"
cp "$repo/include/php_security_patch.sh" "$repo/include/php_boa_patch.sh" "$repo/include/php_boa_patches.txt" "$work/include/"
while read -r version name digest; do
  cp "$fixtures/$name" "$work/src/boa-$name"
done < "$work/include/php_boa_patches.txt"
current_dir=$work
. "$work/include/php_security_patch.sh"
# Extract original release files touched by the series, including context files.
# This avoids scanning thousands of unrelated PHPT tests on Windows.
Extract_Targets() {
  local version="$1" destination="$2" entry name digest
  local -a inputs=()
  while read -r entry name digest; do
    [ "$entry" != "$version" ] || inputs+=("$fixtures/$name")
  done < "$work/include/php_boa_patches.txt"
  awk -v prefix="php-$version/" '/^--- a\// { path=$2; sub(/^a\//, "", path); print prefix path }' "${inputs[@]}" | LC_ALL=C sort -u > "$work/needed"
  tar tzf "$fixtures/php-$version.tar.gz" | LC_ALL=C sort -u > "$work/available"
  LC_ALL=C comm -12 "$work/needed" "$work/available" > "$work/targets"
  tar xzf "$fixtures/php-$version.tar.gz" -C "$destination" -T "$work/targets"
}
for version in 7.4.33 8.1.34; do
  Extract_Targets "$version" "$work"
  cd "$work/php-$version"
  Apply_PHP_Security_Patch "$version" > "$work/apply.log" 2>&1 || { tail -40 "$work/apply.log"; exit 1; }
  Apply_PHP_Security_Patch "$version" > "$work/repeat.log" 2>&1 || { tail -40 "$work/repeat.log"; exit 1; }
  grep -q 'series already applied' "$work/repeat.log"
  echo "PASS: PHP $version pristine source and repeat application"
done
# Reject a modified patch before touching source.
printf '\ncorrupt\n' >> "$work/src/boa-php-8.1.34-cve-2026-129291.patch"
if Apply_PHP_Security_Patch 8.1.34 > "$work/corrupt.log" 2>&1; then
  echo 'FAIL: modified patch accepted'; exit 1
fi
cp "$fixtures/php-8.1.34-cve-2026-129291.patch" "$work/src/boa-php-8.1.34-cve-2026-129291.patch"
# An incompatible source must fail validation without modifying the build tree.
mkdir "$work/incompatible"
Extract_Targets 8.1.34 "$work/incompatible"
cd "$work/incompatible/php-8.1.34"
printf 'incompatible\n' > sapi/fpm/fpm/fpm_children.c
find . -type f -print0 | sort -z | xargs -0 sha256sum > "$work/before"
if Apply_PHP_Security_Patch 8.1.34 > "$work/incompatible.log" 2>&1; then
  echo 'FAIL: incompatible source accepted'; exit 1
fi
find . -type f -print0 | sort -z | xargs -0 sha256sum > "$work/after"
cmp "$work/before" "$work/after"
echo 'PASS: modified patch rejected; incompatible source rejected without changes'
