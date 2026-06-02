# libfprint VFS0090 packages

Debian trixie packages for the `138a:0090` Validity/Synaptics VFS7500 Touch Fingerprint Sensor used in some 2016-era ThinkPads, including the X1 Yoga.

Stock Debian trixie ships `libfprint` without this reader. This repo publishes a rebuilt `libfprint-2-2` based on upstream `libfprint` 1.94.10 with the VFS0090/VFS0097 driver integrated, plus a small metapackage:

```text
libfprint-2-2              rebuilt libfprint with vfs0090 integrated
libfprint-2-tod-vfs0090    metapackage depending exactly on the matching libfprint-2-2
```

Despite the `tod` name, this is not an external TOD plugin. The driver is integrated into the normal `libfprint-2-2` shared library. The metapackage gives apt users one obvious package to install or remove.

## Supported device

Check for the USB device:

```sh
lsusb | grep -Ei '138a|validity|finger|synaptics'
```

Expected output includes:

```text
ID 138a:0090 Validity Sensors, Inc. VFS7500 Touch Fingerprint Sensor
```

The upstream VFS0090 work also includes `138a:0097`. This repo was built and tested for Debian trixie on `138a:0090`.

## Install on Debian trixie

Add the repository signing key:

```sh
sudo install -d -m 0755 /etc/apt/keyrings
curl -fsSL https://raw.githubusercontent.com/jamesyc/libfprint/main/keys/libfprint-vfs0090.asc |
  sudo tee /etc/apt/keyrings/libfprint-vfs0090.asc >/dev/null
```

The current apt signing key fingerprint is:

```text
54B4 E36B 9FB4 891F D50C  2380 51F7 5602 6D9D 8A4F
```

Add this GitHub-hosted apt repository:

```sh
echo 'deb [arch=amd64 signed-by=/etc/apt/keyrings/libfprint-vfs0090.asc] https://raw.githubusercontent.com/jamesyc/libfprint/main/apt trixie main' |
  sudo tee /etc/apt/sources.list.d/libfprint-vfs0090.list
```

Install:

```sh
sudo apt update
sudo apt install fprintd libpam-fprintd libfprint-2-tod-vfs0090
```

Verify:

```sh
dpkg -l | awk '/libfprint|fprintd/ {print $1, $2, $3}'
```

Expected key lines:

```text
ii libfprint-2-2             1:1.94.10+vfs0090-1~deb13vfs1
ii libfprint-2-tod-vfs0090   1:1.94.10+vfs0090-1~deb13vfs1
ii fprintd                   1.94.5-2
ii libpam-fprintd            1.94.5-2
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
fprintd-list "$USER"
fprintd-enroll "$USER"
```

On GNOME, the device should also appear in Settings after `fprintd` can list it.

For PAM login integration on Debian:

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

If `fprintd-list "$USER"` says `No devices available` and the journal says `Sensor not initialized, init byte is 0x2`, the package is installed and the driver is loading; the initializer still needs to complete.

## Uninstall

Remove the metapackage and runtime tools:

```sh
sudo apt remove libfprint-2-tod-vfs0090 fprintd libpam-fprintd
```

Return to Debian's stock `libfprint`:

```sh
sudo apt install --allow-downgrades libfprint-2-2=1:1.94.9-1
```

Remove the repository:

```sh
sudo rm -f /etc/apt/sources.list.d/libfprint-vfs0090.list
sudo rm -f /etc/apt/keyrings/libfprint-vfs0090.asc
sudo apt update
```

## Build notes

The binary package build passed the upstream test suite:

```text
Ok:   124
Fail: 0
```

The source package is included under `source/`, and the integrated driver patch is under `patches/`. The patch does five things:

- adds the `vfs0090` driver sources
- adds `vfs0090` to the Meson driver list
- links the driver against NSS/OpenSSL dependencies available in Debian trixie
- moves `138a:0090` and `138a:0097` out of libfprint's generated unsupported-device list
- adds `libfprint-2-tod-vfs0090` as a compatibility metapackage with an exact dependency on the matching `libfprint-2-2`

Driver and initializer behavior are based on the VFS0090 work in [3v1n0/libfprint](https://github.com/3v1n0/libfprint). The base `libfprint` version used here is upstream 1.94.10 from [freedesktop/libfprint](https://gitlab.freedesktop.org/libfprint/libfprint).
