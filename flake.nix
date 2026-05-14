# SPDX-License-Identifier: copyleft-next-0.3.1
#
# Library flake: NixOS modules, overlays, templates, and custom
# packages for provisioning NixOS systems. Two backend modules
# differ in the artifact each produces — imageless yields a system
# closure booted directly by QEMU, libvirt yields a qcow2 disk
# image.
#
# Validate both backends:
#   nix flake check
#
# Build a single backend closure:
#   nix build .#checks.x86_64-linux.imageless
#   nix build .#checks.x86_64-linux.libvirt
#
# Build an individual custom package:
#   nix build .#cpupower
#
# Create a downstream configuration:
#   nix flake init --template "github:linux-kdevops/nixos-flake"
#   nix flake init --template "github:linux-kdevops/nixos-flake#libvirt"
{
  description = "NixOS modules, overlays, and templates for provisioning NixOS systems";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";

  outputs =
    { self, nixpkgs }:
    {
    };
}
