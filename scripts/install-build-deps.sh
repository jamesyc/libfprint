#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
work_dir="${1:-"$repo_root/.build-deps"}"

if [[ "$(id -u)" != 0 ]]; then
  echo "error: run this script as root so it can install build dependencies" >&2
  exit 1
fi

export DEBIAN_FRONTEND=noninteractive

apt-get update
apt-get install -y --no-install-recommends \
  ca-certificates \
  devscripts \
  dpkg-dev \
  equivs \
  git

rm -rf "$work_dir"
mkdir -p "$work_dir"

dsc="$(find "$repo_root/source" -maxdepth 1 -name 'libfprint_*.dsc' | sort | tail -n 1)"
if [[ -z "$dsc" ]]; then
  echo "error: no source/libfprint_*.dsc file found" >&2
  exit 1
fi

dpkg-source -x "$dsc" "$work_dir/source"
mk-build-deps \
  --install \
  --remove \
  --tool 'apt-get -y --no-install-recommends' \
  "$work_dir/source/debian/control"

