# SPDX-License-Identifier: copyleft-next-0.3.1
#
# Shorter boot for an imageless guest, measured from QEMU's start to the
# first SSH login.
#
# The imageless root is a fresh tmpfs, so every boot is a first boot:
# the settings below drop first-boot work that sits on the way to a
# login. The profile also builds system.build.minimalInitrd, an
# initramfs that boots the closure without the systemd initramfs.
#
# Usage in a flake:
#   modules = [
#     knix.nixosModules.backends.imageless
#     knix.nixosModules.profiles.fast-boot
#   ];
#
# QEMU's initramfs and kernel command line, without the systemd
# initramfs:
#
#   -initrd <system.build.minimalInitrd>/initrd
#   -append "console=ttyS0 CLOSURE=<toplevel>"
#
# root= stays off: with no root device named, the kernel makes its
# initial root a tmpfs (init/do_mounts.c), which is the imageless /.
# rdinit= stays off too, so the kernel runs the initramfs's /init
# (kernel_init() in init/main.c); init= is tried only when that fails.
# The kernel hands CLOSURE=, a parameter it does not know, to init as an
# environment variable (unknown_bootoption() in init/main.c).
#
# Three more settings belong on the command line, for any initramfs.
# systemd asks the console for its terminal type and size with ANSI
# queries and waits 333 ms for each answer
# (CONSOLE_ANSI_SEQUENCE_TIMEOUT_USEC, src/basic/terminal-util.c); a
# serial console never answers, and it asks again after switch-root.
# systemd.tty.term.console=vt220, systemd.tty.rows.console=24 and
# systemd.tty.columns.console=80 answer in advance (kernel-command-line(7)).
# systemd also holds back starting a mount while more than five mount
# events a second arrive (mount_rate_limit_burst, src/core/mount.c);
# SYSTEMD_DEFAULT_MOUNT_RATE_LIMIT_BURST=1000 raises the limit. That is
# safe here because the imageless kernel has virtiofs built in: with
# virtiofs as a module, the store's mount can run before the tag exists.
# systemd.condition_first_boot=false skips the preset pass a first boot
# runs (src/core/main.c). boot.json cannot carry them: nixpkgs writes
# kernelParams into bootspec only when it builds the kernel
# (nixos/modules/system/activation/bootspec.nix).
{
  config,
  lib,
  pkgs,
  ...
}:
let
  # PID 1 until the closure's stage 2 takes over. prepare-root reads
  # /proc/cmdline and writes through /dev/fd first, hence those two.
  # With /proc mounted it skips its own early mounts (the /proc/1 test
  # in stage-2-init.sh), and the activation's specialfs snippet mounts
  # /sys, /run and the rest. Without a usable CLOSURE= the exec would
  # fail and panic the kernel, so that drops to a shell like a failed
  # store mount.
  init = pkgs.writeText "init" ''
    #!/bin/busybox sh
    /bin/busybox mkdir --parents /dev /proc /nix/store
    /bin/busybox mount -t devtmpfs devtmpfs /dev
    /bin/busybox mount -t proc proc /proc
    /bin/busybox ln -s /proc/self/fd /dev/fd
    exec </dev/console >/dev/console 2>&1
    /bin/busybox mount -t virtiofs store /nix/store || exec /bin/busybox sh
    [ -x "$CLOSURE/prepare-root" ] || exec /bin/busybox sh
    exec "$CLOSURE/prepare-root"
  '';
in
{
  assertions = [
    {
      # With the systemd initramfs and nixos-init off, NixOS copies its
      # stage 2 script to $toplevel/prepare-root
      # (nixos/modules/system/activation/top-level.nix); run as PID 1 it
      # mounts what is missing, runs the activation and starts systemd
      # (nixos/modules/system/boot/stage-2-init.sh). nixos-init replaces
      # it and does not yet run without an initramfs.
      assertion = config.boot.initrd.systemd.enable && !config.system.nixos-init.enable;
      message = "knix.profiles.fast-boot needs the systemd initramfs with system.nixos-init.enable off, for $toplevel/prepare-root.";
    }
  ];

  # NixOS generates an RSA 4096 and an Ed25519 host key by default
  # (services.openssh.hostKeys), and the first login waits for
  # sshd-keygen.service; the RSA key takes most of that time.
  services.openssh.hostKeys = [
    {
      type = "ed25519";
      path = "/etc/ssh/ssh_host_ed25519_key";
    }
  ];

  # pam_systemd registers each SSH login with logind, and the first one
  # starts root's user manager before the command runs. The sshd module
  # sets startSession, hence mkForce; logins then have no logind session.
  security.pam.services.sshd.startSession = lib.mkForce false;

  # systemd-vconsole-setup sets the keymap and font of virtual terminals,
  # which a serial or virtio console does not have; console.enable is
  # what pulls it into the initramfs and the system (config/console.nix).
  console.enable = false;

  # Both carry ConditionNeedsUpdate=/var, which a fresh /var always
  # meets, and sysinit.target waits for them.
  systemd.suppressedSystemUnits = [
    "systemd-journal-catalog-update.service"
    "systemd-update-done.service"
  ];

  # The archive's / becomes the guest's /, and sshd refuses an
  # authorized keys file under a directory writable by group or others
  # (safe_path() in OpenSSH's misc.c), so every mode is set here rather
  # than taken from the build's umask.
  system.build.minimalInitrd =
    pkgs.runCommand "initrd-prepare-root" { nativeBuildInputs = [ pkgs.cpio ]; }
      ''
        mkdir --parents root/bin
        cp ${pkgs.pkgsStatic.busybox}/bin/busybox root/bin/busybox
        cp ${init} root/init
        chmod 0755 root root/bin root/bin/busybox root/init
        find root -exec touch --no-dereference --date=@0 {} +
        mkdir $out
        (cd root && find . | sort | cpio --quiet --create --format=newc --owner=0:0 --reproducible > $out/initrd)
      '';
}
