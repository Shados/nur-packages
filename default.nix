{ pkgs ? import <nixpkgs> { } }:
{
  lib = import ./lib { inherit pkgs; };
  modules = import ./modules;
  overlays = import ./modules;

  urxvt-config-reload = pkgs.callPackage ./pkgs/urxvt-config-reload {
    inherit (pkgs.perlPackages) AnyEvent LinuxFD CommonSense SubExporter
      DataOptList ParamsUtil SubInstall;
  };
  urxvtconfig = pkgs.callPackage ./pkgs/urxvtconfig {
    inherit (pkgs.qt5) qtbase qmake;
    inherit (pkgs.xorg) libXft;
  };
}
