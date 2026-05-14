# nixos-flake

NixOS modules, overlays, and templates for provisioning NixOS
systems. The flake exposes two backend modules that differ in the
artifact each produces and in how the system boots:

- **imageless**: a system closure that boots a VM directly — tmpfs
  root, systemd initramfs, external kernel, `/nix/store` and
  `/lib/modules` mounted via virtiofs from the host. No disk image
  and nothing persists across boots.
- **libvirt**: a qcow2 disk image consumed by libvirt — `/dev/vda`
  root, grub bootloader, NixOS-built kernel, DHCP from libvirt's
  default network.

Both compose with the opt-in modules — `user`, the mounts modules
(`shares`, `storage`), the profiles (`devel`, `build-tools`,
`monitoring`), and the per-suite modules under `testSuites.*` —
so a system can be minimal or carry the full kernel and storage
testing toolchain.

**License**: copyleft-next-0.3.1

## Prerequisites

The [Nix package manager](https://nixos.org/download/) with flake
support enabled:

```shell
mkdir --parents ~/.config/nix
echo 'experimental-features = nix-command flakes' >> ~/.config/nix/nix.conf
```

## Quick start

Validate that both backends evaluate and build:

```shell
nix flake check
```

Build a single backend closure:

```shell
nix build .#checks.x86_64-linux.imageless    # or .libvirt
readlink --canonicalize result
```

The `result` symlink points to the system closure. For imageless,
`result/boot.json` contains the `init` and `initrd` paths needed to
configure QEMU:

```shell
cat result/boot.json
```

To create a downstream configuration, use a template:

```shell
nix flake init --template "github:linux-kdevops/nixos-flake#imageless"
nix flake init --template "github:linux-kdevops/nixos-flake#libvirt"
```

See [docs/usage.md](docs/usage.md) for customizing packages and
NixOS options.

## How it boots

### Imageless

This backend builds two artifacts: a NixOS system closure and a
systemd initramfs. Booting requires an external kernel and QEMU
with virtiofsd sharing the host's `/nix/store` and `/lib/modules`
into the guest.

The external kernel must have the boot-critical virtio drivers
built-in (`CONFIG_VIRTIO_FS=y`, `CONFIG_VIRTIO_PCI=y`,
`CONFIG_TMPFS=y`). All other drivers can be kernel modules loaded
from `/lib/modules` after switch-root.

QEMU needs two virtiofsd instances sharing host directories into
the guest with these tags:

- `store`: the host's `/nix/store` (read-only)
- `modules`: the kernel build's `/lib/modules` directory

The kernel command line:

```
root=tmpfs console=ttyS0,115200 console=hvc0 init=/nix/store/<hash>/init
```

systemd in the initramfs reads the NixOS-generated fstab, mounts
root (tmpfs), `/nix/store` (virtiofs tag `store`), and
`/lib/modules` (virtiofs tag `modules`), then switch-roots into
the system closure. The `init=` and `initrd` paths change on
every rebuild and are available in `result/boot.json`.

### Libvirt

This backend builds a full NixOS system closure including its own
kernel. The consumer supplies a qcow2 disk image containing the
closure; libvirt presents it to the guest as `/dev/vda`. Grub on
the MBR loads the kernel, initramfs mounts the ext4 root from
`/dev/vda1`, and systemd activation proceeds normally. Networking
comes up via DHCP from libvirt's default network (typically
`192.168.122.0/24`).

## Documentation

| Document | Content |
|---|---|
| [docs/usage.md](docs/usage.md) | Configurations, modules, overlays, packages, home overlay, block-device filesystems |
| [docs/design-decisions.md](docs/design-decisions.md) | Imageless and libvirt boot model, upstream references |
| [docs/verifying.md](docs/verifying.md) | Pre-commit checklist: format, flake check, image and package builds |

## Related work

- [run-kernel](https://github.com/metaspace/run-kernel). Rust init + NixOS boot via virtiofs. The direct inspiration for the imageless boot model.
- [nixos-shell](https://github.com/Mic92/nixos-shell). Nix-based lightweight QEMU VMs with host mounts.
- [kernel-development-flake](https://github.com/jordanisaacs/kernel-development-flake). Nix flake for Linux kernel development with QEMU.
