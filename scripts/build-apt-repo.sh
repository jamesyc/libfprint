#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
artifacts_dir="${1:-"$repo_root/.build/artifacts"}"
site_dir="${2:-"$repo_root/public"}"
suites_text="${APT_SUITES:-any trixie}"
component="${APT_COMPONENT:-main}"
arch="${APT_ARCH:-amd64}"
signing_key="${APT_SIGNING_KEY:-6FF64038E8012499E58B9FF36DC63E5D005DE774}"
read -r -a suites <<< "$suites_text"

main_deb="$(find "$artifacts_dir" -maxdepth 1 -name "libfprint-2-2_*_${arch}.deb" | sort | tail -n 1)"
meta_deb="$(find "$artifacts_dir" -maxdepth 1 -name "libfprint-2-vfs0090_*_${arch}.deb" | sort | tail -n 1)"

if [[ -z "$main_deb" || -z "$meta_deb" ]]; then
  echo "error: expected libfprint-2-2 and libfprint-2-vfs0090 debs in $artifacts_dir" >&2
  exit 1
fi

rm -rf "$site_dir"
mkdir -p \
  "$site_dir/apt/pool/main" \
  "$site_dir/keys"

cp "$main_deb" "$meta_deb" "$site_dir/apt/pool/main/"
cp "$repo_root/keys/libfprint-vfs0090.asc" "$site_dir/keys/"

cat > "$site_dir/index.html" <<'HTML'
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <title>libfprint VFS0090 apt repo</title>
</head>
<body>
  <h1>libfprint VFS0090 apt repo</h1>
  <p>This site hosts the signed apt repository for jamesyc/libfprint.</p>
  <pre>deb [arch=amd64 signed-by=/etc/apt/keyrings/libfprint-vfs0090.asc] https://jamesyc.github.io/libfprint/apt any main</pre>
</body>
</html>
HTML

gpg_sign() {
  if [[ -n "${APT_GPG_PASSPHRASE:-}" ]]; then
    printf '%s' "$APT_GPG_PASSPHRASE" |
      gpg --batch --yes --pinentry-mode loopback --passphrase-fd 0 --local-user "$signing_key" "$@"
  else
    gpg --batch --yes --local-user "$signing_key" "$@"
  fi
}

(
  cd "$site_dir/apt"

  for suite in "${suites[@]}"; do
    mkdir -p "dists/$suite/$component/binary-$arch"
    dpkg-scanpackages --arch "$arch" "pool/main" > "dists/$suite/$component/binary-$arch/Packages"
    gzip -9 -n -k -f "dists/$suite/$component/binary-$arch/Packages"

    apt-ftparchive \
      -o "APT::FTPArchive::Release::Origin=jamesyc/libfprint" \
      -o "APT::FTPArchive::Release::Label=libfprint-vfs0090" \
      -o "APT::FTPArchive::Release::Suite=$suite" \
      -o "APT::FTPArchive::Release::Codename=$suite" \
      -o "APT::FTPArchive::Release::Architectures=$arch" \
      -o "APT::FTPArchive::Release::Components=$component" \
      -o "APT::FTPArchive::Release::Description=libfprint VFS0090 packages" \
      release "dists/$suite" > "dists/$suite/Release"
  done
)

for suite in "${suites[@]}"; do
  gpg_sign --armor --detach-sign \
    --output "$site_dir/apt/dists/$suite/Release.gpg" \
    "$site_dir/apt/dists/$suite/Release"
  gpg_sign --clearsign \
    --output "$site_dir/apt/dists/$suite/InRelease" \
    "$site_dir/apt/dists/$suite/Release"

  gpg --verify "$site_dir/apt/dists/$suite/InRelease"
  gpg --verify "$site_dir/apt/dists/$suite/Release.gpg" "$site_dir/apt/dists/$suite/Release"
done

find "$site_dir" -type f | sort
