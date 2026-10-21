# SPDX-License-Identifier: copyleft-next-0.3.1
#
# Package overlays and custom packages. Each directory here modifies
# one nixpkgs package: overlay.nix is the overlay, and its patches sit
# under patches/. Custom packages not in nixpkgs are defined in pkgs/
# using callPackage and merged here.
#
# Usage in a NixOS module:
#   { nixpkgs.overlays = [ (import ./overlays) ]; }
#
# Reference: https://nixos.org/manual/nixpkgs/stable/#chap-overlays
final: prev:
prev.lib.composeManyExtensions [
  (import ./fio/overlay.nix)
  (import ./xfstests/overlay.nix)
  (import ./xfsprogs/overlay.nix)
  (import ./xfsdump/overlay.nix)
  (import ./spdk/overlay.nix)
  (overlayFinal: _: import ../pkgs overlayFinal)
] final prev
