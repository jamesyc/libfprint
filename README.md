# libfprint VFS0090 packages

Debian and Ubuntu packages for the `138a:0090` Validity/Synaptics VFS7500 Touch Fingerprint Sensor used in some 2016-era ThinkPads, including the X1 Yoga.

Stock Debian trixie ships `libfprint` without this reader. This repo publishes a rebuilt `libfprint-2-2` based on upstream `libfprint` 1.94.10 with the VFS0090/VFS0097 driver integrated:

```text
libfprint-2-2              rebuilt libfprint with vfs0090 integrated
libfprint-2-vfs0090        metapackage depending on the matching libfprint-2-2 and fprintd
```

## Supported device

Check for the USB device:

```sh
lsusb | grep -Ei '138a|validity|finger|synaptics'
```

Expected output includes:

```text
ID 138a:0090 Validity Sensors, Inc. VFS7500 Touch Fingerprint Sensor
```

The upstream VFS0090 work includes support for `138a:0097` and  `138a:0090`.

## Install on Debian

These instructions were tested on Debian 13/trixie.

Add the repository signing key:

```sh
sudo install -d -m 0755 /etc/apt/keyrings
curl -fsSL https://jamesyc.github.io/libfprint/keys/libfprint-vfs0090.asc |
  sudo tee /etc/apt/keyrings/libfprint-vfs0090.asc >/dev/null
```

The current apt signing key fingerprint is: `6FF6 4038 E801 2499 E58B  9FF3 6DC6 3E5D 005D E774`

Add this apt repository:

```sh
echo 'deb [arch=amd64 signed-by=/etc/apt/keyrings/libfprint-vfs0090.asc] https://jamesyc.github.io/libfprint/apt any main' |
  sudo tee /etc/apt/sources.list.d/libfprint-vfs0090.list
```

Install:

```sh
sudo apt update
sudo apt install libfprint-2-vfs0090
```

Verify:

```sh
dpkg -l | awk '/libfprint|fprintd/ {print $1, $2, $3}'
```

Expected key lines:

```text
ii libfprint-2-2             1:1.94.10+vfs0090-1~deb13vfs1
ii libfprint-2-vfs0090       1:1.94.10+vfs0090-1~deb13vfs1
ii fprintd                   1.94.5-2
ii libpam-fprintd            1.94.5-2
```

## Install on Ubuntu

These instructions are for Ubuntu 24.04 LTS/noble or newer on `amd64`.

This Debian-built binary has not been rebuilt natively as a Launchpad PPA. It should
only be used on Ubuntu releases where apt can satisfy the t64 runtime
dependencies, especially `libglib2.0-0t64` and `libssl3t64`.

Add the repository signing key:

```sh
sudo install -d -m 0755 /etc/apt/keyrings
curl -fsSL https://jamesyc.github.io/libfprint/keys/libfprint-vfs0090.asc |
  sudo tee /etc/apt/keyrings/libfprint-vfs0090.asc >/dev/null
```

The current apt signing key fingerprint is: `6FF6 4038 E801 2499 E58B  9FF3 6DC6 3E5D 005D E774`


Add this apt repository:

```sh
echo 'deb [arch=amd64 signed-by=/etc/apt/keyrings/libfprint-vfs0090.asc] https://jamesyc.github.io/libfprint/apt any main' |
  sudo tee /etc/apt/sources.list.d/libfprint-vfs0090.list
```

Update apt and inspect the candidate before installing:

```sh
sudo apt update
apt-cache policy libfprint-2-2 libfprint-2-vfs0090
```

The candidate for both packages should be `1:1.94.10+vfs0090-1~deb13vfs1` from
`jamesyc.github.io/libfprint`.

Install:

```sh
sudo apt install libfprint-2-vfs0090
```

Verify that apt selected this repo's package:

```sh
apt-cache policy libfprint-2-2 libfprint-2-vfs0090
dpkg -l | awk '/libfprint|fprintd/ {print $1, $2, $3}'
```

To uninstall on Ubuntu and return to Ubuntu's stock `libfprint`:

```sh
sudo apt remove libfprint-2-vfs0090
sudo rm -f /etc/apt/sources.list.d/libfprint-vfs0090.list
sudo rm -f /etc/apt/keyrings/libfprint-vfs0090.asc
sudo apt update
apt-cache madison libfprint-2-2
stock_version="$(apt-cache madison libfprint-2-2 | awk '$1 == "libfprint-2-2" {print $3; exit}')"
sudo apt install --allow-downgrades "libfprint-2-2=$stock_version" fprintd libpam-fprintd
```

## Initialize the sensor

The VFS0090 driver expects the sensor to be initialized and paired before `fprintd` can use it. If initialization has not happened yet, `fprintd` can see the driver but logs this:

```text
Sensor not initialized, init byte is 0x2
```

Install and connect `validity-sensors-tools`:

```sh
sudo snap install validity-sensors-tools
sudo snap connect validity-sensors-tools:raw-usb
sudo snap connect validity-sensors-tools:hardware-observe
```

Run the initializer from `/tmp`:

```sh
cd /tmp
sudo validity-sensors-tools.initializer
```

The initializer prompts before it resets and associates the sensor with the current laptop. Read that prompt carefully. If it fails under sudo with a working-directory permission error, running it from `/tmp` avoids that snap/helper issue.

## Enroll fingerprints

After initialization:

```sh
sudo systemctl restart fprintd
sudo fprintd-list "$USER"
sudo fprintd-enroll "$USER"
```

On GNOME, the device should also appear in Settings after `fprintd` can list it.

For PAM login integration on Debian or Ubuntu:

```sh
sudo pam-auth-update
```

Enable the fingerprint PAM profile if it is not already enabled.

## Troubleshooting

Check that the USB device exists:

```sh
lsusb | grep 138a:0090
```

Check that udev has the libfprint autosuspend entry:

```sh
grep -A3 -B2 '138Ap0090' /usr/lib/udev/hwdb.d/*libfprint*
```

Check `fprintd` logs:

```sh
sudo journalctl -u fprintd -n 80 --no-pager
```

If `sudo fprintd-list "$USER"` says `No devices available` and the journal says `Sensor not initialized, init byte is 0x2`, the package is installed and the driver is loading; the initializer still needs to complete.

## Uninstall

Remove the metapackage:

```sh
sudo apt remove libfprint-2-vfs0090
```

Remove the repository before reinstalling stock packages:

```sh
sudo rm -f /etc/apt/sources.list.d/libfprint-vfs0090.list
sudo rm -f /etc/apt/keyrings/libfprint-vfs0090.asc
sudo apt update
```

Find the stock distro version. This should list Debian or Ubuntu, not `jamesyc.github.io`:

```sh
apt-cache madison libfprint-2-2
```

Downgrade or reinstall the stock distro package:

```sh
stock_version="$(apt-cache madison libfprint-2-2 | awk '$1 == "libfprint-2-2" {print $3; exit}')"
sudo apt install --allow-downgrades "libfprint-2-2=$stock_version" fprintd libpam-fprintd
```

## Build notes

The source package is included under `source/`, and the integrated driver patches are under `patches/`. GitHub Actions builds the binary packages from that source package and publishes the signed apt repository under GitHub Pages. 

- `0001-vfs0090-import-driver.patch` imports the driver sources from the VFS0090 upstream work
- `0002-vfs0090-adapt-driver-to-libfprint-1.94.10.patch` carries the local integrated-libfprint and enrollment fixes
- `0003-vfs0090-enable-driver-build.patch` adds the Meson/NSS/OpenSSL build wiring
- `0004-vfs0090-mark-devices-supported.patch` moves `138a:0090` and `138a:0097` into supported-device metadata

The Debian packaging also adds `libfprint-2-vfs0090` as a metapackage. It depends on the matching custom `libfprint-2-2` and `fprintd`, and recommends `libpam-fprintd`.

Driver and initializer behavior are based on the VFS0090 work in [3v1n0/libfprint](https://github.com/3v1n0/libfprint). The base `libfprint` version used here is upstream 1.94.10 from [freedesktop/libfprint](https://gitlab.freedesktop.org/libfprint/libfprint).
