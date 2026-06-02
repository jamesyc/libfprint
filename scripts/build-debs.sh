#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
build_root="${1:-"$repo_root/.build"}"
artifacts_dir="${2:-"$build_root/artifacts"}"
expected_version="${EXPECTED_VERSION:-1:1.94.10+vfs0090-1~deb13vfs1}"

rm -rf "$build_root"
mkdir -p "$build_root" "$artifacts_dir"

dsc="$(find "$repo_root/source" -maxdepth 1 -name 'libfprint_*.dsc' | sort | tail -n 1)"
if [[ -z "$dsc" ]]; then
  echo "error: no source/libfprint_*.dsc file found" >&2
  exit 1
fi

dpkg-source -x "$dsc" "$build_root/source"

while IFS= read -r patch_file; do
  debian_patch="$build_root/source/debian/patches/$(basename "$patch_file")"
  if ! cmp -s "$patch_file" "$debian_patch"; then
    echo "error: $patch_file does not match source package $debian_patch" >&2
    exit 1
  fi
done < <(find "$repo_root/patches" -maxdepth 1 -type f \( -name '*.patch' -o -name series \) | sort)

version="$(dpkg-parsechangelog -l "$build_root/source/debian/changelog" -S Version)"
if [[ "$version" != "$expected_version" ]]; then
  echo "error: package version is $version, expected $expected_version" >&2
  exit 1
fi

(
  cd "$build_root/source"
  dpkg-buildpackage -B -us -uc
)

find "$build_root" -maxdepth 1 -type f \( -name '*.deb' -o -name '*.buildinfo' -o -name '*.changes' \) \
  -exec cp -v {} "$artifacts_dir/" \;

main_deb="$(find "$artifacts_dir" -maxdepth 1 -name 'libfprint-2-2_*_amd64.deb' | sort | tail -n 1)"
meta_deb="$(find "$artifacts_dir" -maxdepth 1 -name 'libfprint-2-vfs0090_*_amd64.deb' | sort | tail -n 1)"

if [[ -z "$main_deb" || -z "$meta_deb" ]]; then
  echo "error: expected libfprint-2-2 and libfprint-2-vfs0090 debs were not built" >&2
  exit 1
fi

main_version="$(dpkg-deb -f "$main_deb" Version)"
meta_version="$(dpkg-deb -f "$meta_deb" Version)"
meta_package="$(dpkg-deb -f "$meta_deb" Package)"
meta_depends="$(dpkg-deb -f "$meta_deb" Depends)"

if [[ "$main_version" != "$expected_version" || "$meta_version" != "$expected_version" ]]; then
  echo "error: built package versions do not match $expected_version" >&2
  exit 1
fi

if [[ "$meta_package" == *tod* ]]; then
  echo "error: metapackage name still contains TOD: $meta_package" >&2
  exit 1
fi

if [[ "$meta_depends" != *"libfprint-2-2 (= $main_version)"* ]]; then
  echo "error: metapackage does not depend on matching libfprint-2-2" >&2
  echo "Depends: $meta_depends" >&2
  exit 1
fi

sha256sum "$main_deb" "$meta_deb"

