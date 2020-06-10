{ pkgs ? import <nixpkgs> { } }:
let
  nixpkgsPath = pkgs.path;
in
rec {
  lib = import ./lib { inherit pkgs; };
  modules = import ./modules;
  overlays = import ./modules;

  ## Packages

  firefox-common = opts: with pkgs; callPackage
    (import nixpkgsPath + /pkgs/applications/networking/browsers/firefox/common.nix opts)
    { inherit (gnome2) libIDL;
      libpng = libpng_apng;
      gnused = gnused_422;
      icu = icu63;
      inherit (darwin.apple_sdk.frameworks) CoreMedia ExceptionHandling
                                            Kerberos AVFoundation MediaToolbox
                                            CoreLocation Foundation AddressBook;
      inherit (darwin) libobjc;
      inherit (rustPackages) cargo rustc;

      enableOfficialBranding = false;
      privacySupport = true;
    };

  tagsistant = pkgs.callPackage ./pkgs/tagsistant { };
  urxvt-config-reload = pkgs.callPackage ./pkgs/urxvt-config-reload {
    inherit (pkgs.perlPackages) AnyEvent LinuxFD CommonSense SubExporter
      DataOptList ParamsUtil SubInstall;
  };
  urxvtconfig = pkgs.callPackage ./pkgs/urxvtconfig {
    inherit (pkgs.qt5) qtbase qmake;
    inherit (pkgs.xorg) libXft;
  };

  waterfox = pkgs.wrapFirefox waterfox-unwrapped {
    browserName = "waterfox";
    nameSuffix = "";
  };
  waterfox-unwrapped = pkgs.callPackage ./pkgs/waterfox {
    inherit firefox-common nixpkgsPath;
  };
}
