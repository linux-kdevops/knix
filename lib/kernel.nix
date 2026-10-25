# SPDX-License-Identifier: copyleft-next-0.3.1
#
# A kernel built as a derivation from the same configuration commands a
# developer types in the build-kernel shell. `configure` runs in the source
# tree with $B as the build directory, exactly as on the command line:
#
#   knix.lib.buildKernel pkgs {
#     src = pkgs.fetchurl { ... };
#     version = "7.3";
#     configure = ''
#       make O=$B defconfig kvm_guest.config
#       scripts/config --file $B/.config --enable VIRTIO_FS
#       make O=$B olddefconfig
#     '';
#   }
#
# The result is nixpkgs' linuxManualConfig: bzImage in the default output,
# lib/modules/<release> in .modules.
#
# Only GCC and the kernel package set of lib/toolchain.nix are on the PATH,
# and linuxManualConfig builds with GCC: `make LLVM=1` fails, and without
# rustc Kconfig cannot offer RUST, so olddefconfig drops a CONFIG_RUST=y.
{ pkgs }:
{
  src,
  version,
  configure,
  # The release the configuration produces, `make kernelrelease`. Only a
  # CONFIG_LOCALVERSION changes it from the padded version; a wrong value
  # fails the build with the right one in the message.
  modDirVersion ? null,
  # Whether the configuration has CONFIG_MODULES=y. linuxManualConfig reads
  # it from the configuration only through import-from-derivation, which
  # this library does not ask of its consumers.
  modules ? true,
}:
let
  tc = import ./toolchain.nix { inherit pkgs; };
  configfile = pkgs.stdenv.mkDerivation {
    pname = "linux-config";
    inherit version src;
    nativeBuildInputs = tc.kernel;
    dontConfigure = true;
    buildPhase = ''
      runHook preBuild
      patchShebangs scripts
      B=$NIX_BUILD_TOP/build
      mkdir -- "$B"
      ${configure}
      runHook postBuild
    '';
    installPhase = ''
      runHook preInstall
      cp -- "$B/.config" "$out"
      runHook postInstall
    '';
  };
in
pkgs.linuxManualConfig {
  inherit
    src
    version
    modDirVersion
    configfile
    ;
  config = pkgs.lib.optionalAttrs modules { CONFIG_MODULES = "y"; };
}
