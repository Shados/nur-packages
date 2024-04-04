self: super: with super.lib; let
  pins = import ../../nix/sources.nix super.path super.targetPlatform.system;
in {
  pythonOverrides = self.lib.buildPythonOverrides (pyself: pysuper: {
    # General language-specific support tools
    flake8-bugbear = pyself.callPackage ./flake8-bugbear.nix { };
    flake8-per-file-ignores = pyself.callPackage ./flake8-per-file-ignores.nix { };

    usb-resetter = pyself.callPackage ./usb-resetter.nix { inherit pins; };
  }) super.pythonOverrides;
}
