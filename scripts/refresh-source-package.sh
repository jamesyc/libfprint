#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
work_root="${1:-"$repo_root/.source-refresh"}"
expected_version="${EXPECTED_VERSION:-1:1.94.10+vfs0090-1~deb13vfs1}"

rm -rf "$work_root"
mkdir -p "$work_root/build"

dsc="$(find "$repo_root/source" -maxdepth 1 -name 'libfprint_*.dsc' | sort | tail -n 1)"
if [[ -z "$dsc" ]]; then
  echo "error: no source/libfprint_*.dsc file found" >&2
  exit 1
fi

dpkg-source -x --skip-patches "$dsc" "$work_root/build/source"

version="$(dpkg-parsechangelog -l "$work_root/build/source/debian/changelog" -S Version)"
if [[ "$version" != "$expected_version" ]]; then
  echo "error: package version is $version, expected $expected_version" >&2
  exit 1
fi

rm -rf "$work_root/build/source/debian/patches"
mkdir -p "$work_root/build/source/debian/patches"
find "$repo_root/patches" -maxdepth 1 -type f ! -name '.*' -name '*.patch' \
  -exec cp {} "$work_root/build/source/debian/patches/" \;
cp "$repo_root/patches/series" "$work_root/build/source/debian/patches/series"

(
  cd "$work_root/build/source"
  dpkg-buildpackage -S -d -us -uc
)

find "$repo_root/source" -maxdepth 1 -type f \
  \( -name 'libfprint_*.debian.tar.xz' \
  -o -name 'libfprint_*.dsc' \
  -o -name 'libfprint_*_source.buildinfo' \
  -o -name 'libfprint_*_source.changes' \) \
  -delete

find "$work_root/build" -maxdepth 1 -type f \
  \( -name 'libfprint_*.debian.tar.xz' \
  -o -name 'libfprint_*.dsc' \) \
  -exec cp -v {} "$repo_root/source/" \;

while IFS= read -r patch_file; do
  debian_patch="$work_root/build/source/debian/patches/$(basename "$patch_file")"
  if ! cmp -s "$patch_file" "$debian_patch"; then
    echo "error: $patch_file does not match regenerated source package patch $debian_patch" >&2
    exit 1
  fi
done < <(find "$repo_root/patches" -maxdepth 1 -type f ! -name '.*' \( -name '*.patch' -o -name series \) | sort)

echo "Regenerated source package files in $repo_root/source"
echo "Source-only .buildinfo and .changes files were left in $work_root/build because they are host-specific upload metadata."
