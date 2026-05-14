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
    let
      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];
      forAllSystems =
        f:
        nixpkgs.lib.genAttrs systems (
          system:
          f (
            import nixpkgs {
              inherit system;
              overlays = [ self.overlays.default ];
            }
          )
        );
    in
    {
      nixosModules = {
        # The default aggregate matches the imageless template's
        # starter composition (imageless backend plus the opt-in
        # workflow account). Consumers that prefer the libvirt backend
        # or want bare modules import them by name.
        default.imports = [
          ./modules/imageless.nix
          ./modules/user.nix
        ];
        build-tools = ./modules/build-tools.nix;
        devel = ./modules/devel.nix;
        imageless = ./modules/imageless.nix;
        libvirt = ./modules/libvirt.nix;
        monitoring = ./modules/monitoring.nix;
        shares = ./modules/shares.nix;
        storage = ./modules/storage.nix;
        user = ./modules/user.nix;
        workflows.blktests = ./modules/workflows/blktests.nix;
        workflows.fstests = ./modules/workflows/fstests.nix;
        workflows.gitr = ./modules/workflows/gitr.nix;
        workflows.ltp = ./modules/workflows/ltp.nix;
        workflows.mmtests = ./modules/workflows/mmtests.nix;
        workflows.pynfs = ./modules/workflows/pynfs.nix;
        workflows.selftests = ./modules/workflows/selftests.nix;
        workflows.sysbench = ./modules/workflows/sysbench.nix;
      };

      overlays = {
        default = import ./overlays;
        fio = import ./overlays/fio.nix;
        xfstests = import ./overlays/xfstests.nix;
        custom-pkgs = final: _: import ./pkgs final;
      };

      # Expose the custom packages as direct flake outputs so they can be
      # built without going through a NixOS configuration.
      packages = forAllSystems (pkgs: {
        inherit (pkgs)
          cpupower
          damo
          libbpf-tools
          nfstest
          pynfs
          xnvme
          ;
      });

      # Tree formatter for `nix fmt`. No overlay needed, so this uses
      # legacyPackages rather than re-importing nixpkgs.
      formatter = nixpkgs.lib.genAttrs systems (
        system: nixpkgs.legacyPackages.${system}.nixfmt-rfc-style
      );

      # Per-backend system closures exercised by nix flake check.
      checks = nixpkgs.lib.genAttrs systems (
        system:
        let
          buildBackend =
            module:
            (nixpkgs.lib.nixosSystem {
              inherit system;
              modules = [
                module
                { nixpkgs.overlays = [ self.overlays.default ]; }
              ];
            }).config.system.build.toplevel;
        in
        {
          imageless = buildBackend self.nixosModules.imageless;
          libvirt = buildBackend self.nixosModules.libvirt;
        }
      );
    };
}
