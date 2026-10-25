# SPDX-License-Identifier: copyleft-next-0.3.1
#
# QEMU built as a derivation with the configure flags a developer passes in
# the build-qemu shell, from the same inputs that shell takes from nixpkgs'
# QEMU:
#
#   knix.lib.buildQemu pkgs {
#     src = pkgs.fetchurl { ... };   # a release tarball
#     version = "11.1.2";
#     configureFlags = [ "--target-list=x86_64-softmmu" "--enable-kvm" ];
#   }
#
# The source must be a release tarball: a git checkout leaves the meson
# subprojects to be downloaded at configure time, which a sandboxed build
# cannot do.
{ pkgs }:
{
  src,
  version,
  configureFlags ? [ ],
}:
pkgs.stdenv.mkDerivation {
  pname = "qemu";
  inherit version src configureFlags;
  # configure's mkvenv requires its "tooling" group (pythondeps.toml) and
  # would fetch what is missing from PyPI; nixpkgs' QEMU of another release
  # need not list it.
  nativeBuildInputs =
    pkgs.qemu.nativeBuildInputs
    ++ (with pkgs.python3Packages; [
      qemu-qmp
      setuptools
      wheel
      pip
    ]);
  # json-c and cmocka for --enable-vfio-user-server, as in the build-qemu
  # shell, which says why.
  buildInputs = pkgs.qemu.buildInputs ++ [
    pkgs.json_c
    pkgs.cmocka
  ];
  # QEMU's configure drives meson and ninja itself, behind make.
  dontUseMesonConfigure = true;
  dontUseNinjaBuild = true;
  dontUseNinjaInstall = true;
  dontAddStaticConfigureFlags = true;
  enableParallelBuilding = true;
  preConfigure = ''
    # The cc-wrapper's CPP breaks configure's dependency calculation.
    unset CPP
    # The tarball ships it mode 0644, so patchShebangs would skip it, yet
    # meson runs it through its shebang.
    chmod +x scripts/shaderinclude.py
    patchShebangs .
  '';
}
