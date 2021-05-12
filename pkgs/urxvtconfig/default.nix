{ stdenv, qmake
, qtbase, imagemagick, fontconfig, libXft
}:

stdenv.mkDerivation rec {
  pname = "urxvtconfig";
  version = "unstable-2017-11-30";

  src = (import ../../nix/sources.nix).urxvtconfig;

  nativeBuildInputs = [
    qmake
  ];
  buildInputs = [
    qtbase imagemagick fontconfig libXft
  ];

  qmakeFlags = [
    "source/URXVTConfig.pro"
  ];
  preConfigure = ''
    substituteInPlace source/URXVTConfig.pro \
      --replace '/usr' "$out"
  '';

  meta = with stdenv.lib; {
    description = "A graphical user interface tool for configuration of the rxvt-unicode terminal emulator.";
    homepage = "https://github.com/daedreth/URXVTConfig";
    license = with licenses; lgpl3;
    maintainers = with maintainers; [
      arobyn
    ];
  };
}
