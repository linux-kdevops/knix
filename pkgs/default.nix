# SPDX-License-Identifier: copyleft-next-0.3.1
#
# Custom packages not available in nixpkgs.
#
# Each package is a directory, as in nixpkgs' pkgs/by-name: package.nix
# declares a function whose arguments are its dependencies, and the files
# it uses (patches under patches/) sit beside it. Use callPackage to
# compose them:
#
#   xnvme = pkgs.callPackage ./xnvme/package.nix { };
#
# The overlay at overlays/default.nix imports this file and merges
# the packages into the nixpkgs set.
#
# Reference: https://nix.dev/tutorials/callpackage
pkgs: {
  blktests = pkgs.callPackage ./blktests/package.nix { };
  bpf-perf-tools = pkgs.callPackage ./bpf-perf-tools/package.nix { };
  cpupower = pkgs.callPackage ./cpupower/package.nix { };
  damo = pkgs.callPackage ./damo/package.nix { };
  dbench = pkgs.callPackage ./dbench/package.nix { };
  ebpf_exporter = pkgs.callPackage ./ebpf_exporter/package.nix { };
  ebpf-fix-latency-tool = pkgs.callPackage ./ebpf-fix-latency-tool/package.nix { };
  ebpf-syscall = pkgs.callPackage ./ebpf-syscall/package.nix { };
  faster-biolatency = pkgs.callPackage ./faster-biolatency/package.nix { };
  fustip = pkgs.callPackage ./fustip/package.nix { };
  kvcache-bench = pkgs.callPackage ./kvcache-bench/package.nix { };
  libbpf-tools = pkgs.callPackage ./libbpf-tools/package.nix { };
  lmcache = pkgs.pkgsUnstable.python313Packages.callPackage ./lmcache/package.nix { };
  nfstest = pkgs.callPackage ./nfstest/package.nix { };
  nvme-bpf = pkgs.callPackage ./nvme-bpf/package.nix { };
  pynfs = pkgs.callPackage ./pynfs/package.nix { };
  systing = pkgs.callPackage ./systing/package.nix { };
  xnvme = pkgs.callPackage ./xnvme/package.nix { };
}
