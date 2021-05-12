{ stdenv, moonscript, buildLuarocksPackage
}:

buildLuarocksPackage rec {
  pname = "earthshine";
  version = "scm-1";

  src = (import ../../nix/sources.nix).earthshine;

  propagatedBuildInputs = [
    moonscript
  ];

  knownRockspec = "${pname}-${version}.rockspec";

  meta = with stdenv.lib; {
    description = "A collection of MoonScript libraries I had a need for";
    homepage = https://github.com/Shados/earthshine;
    hydraPlatforms = platforms.linux;
    maintainers = with maintainers; [ arobyn ];
    license = licenses.bsd2;
  };
}

