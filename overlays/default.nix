{
  # Fixes/workarounds for issues in upstream nixpkgs that I CBF upstreaming (or
  # that would be problematic to upstream)
  fixes = self: super: {
    # Fix flashplayer-standalone hw gpu stuff
    flashplayer-standalone = super.flashplayer-standalone.overrideAttrs(oldAttrs: let
      libs = super.stdenv.lib.makeLibraryPath [ super.libGL ];
    in {
      nativeBuildInputs = with super; oldAttrs.nativeBuildInputs ++ [ makeWrapper libGL ];
      rpath = oldAttrs.rpath + ":" + libs;
    });
  };
  # Pinned old flashplayer versions
  oldflash = self: super: let
    # Helpers {{{
    extractNPAPIFlash = ver: super.runCommand "flash_player_npapi_linux_${ver}.x86_64.tar.gz" {
        src = flashSrcs."${ver}";
        preferLocalBuild = true;
      } ''
        ${pkgs.unzip}/bin/unzip $src
        for f in */*_linux.x86_64.tar.gz; do
          cp $f $out
        done
      '';
    extractStandaloneFlash = ver: super.runCommand "flash_player_sa_linux_${ver}.x86_64.tar.gz" {
        src = flashSrcs."${ver}";
        preferLocalBuild = true;
      } ''
        ${pkgs.unzip}/bin/unzip $src
        for f in */*_linux_sa.x86_64.tar.gz; do
          cp $f $out
        done
      '';
    mkFlashUrl = ver: "https://fpdownload.macromedia.com/pub/flashplayer/installers/archive/fp_${ver}_archive.zip";
    mkFlashSrc = ver: sha256: super.fetchurl {
      url = mkFlashUrl ver;
      inherit sha256;
    };
    mkFlashSrcs = verHashList: let
        version_attrs = map (vh: rec {
          name = builtins.elemAt vh 0;
          value = mkFlashSrc name (builtins.elemAt vh 1);
        }) verHashList;
      in builtins.listToAttrs version_attrs;
    # }}}
    flashSrcs = mkFlashSrcs [
      [ "30.0.0.113" "117hw34bxf5rncfqn6bwvb66k2jv99avv1mxnc2pgvrh63bp3isp" ]
      [ "30.0.0.134" "1cffzzkg6h8bns3npkk4a87qqfnz0nlr7k1zjfc2s2wzbi7a94cc" ]
      [ "30.0.0.154" "14p0lcj8x09ivk1h786mj0plzz2lkvxkbw3w15fym7pd0nancz88" ]
      [ "31.0.0.108" "06kvwlzw2bjkcxzd1qvrdvlp0idvm54d1rhzn5vq1vqdhs0lnv76" ]
      [ "31.0.0.122" "1rnxqw8kn96cqf821fl209bcmqva66j2p3wq9x4d43d8lqmsazhv" ]
      [ "32.0.0.171" "1zln5m82va44nzypkx5hdkq6kk3gh7g4sx3q603hw8rys0bq22bb" ]
      [ "32.0.0.293" "08igfnmqlsajgi7njfj52q34d8sdn8k88cij7wvgdq53mxyxlian" ]
    ];
  in {
    flashplayer = let
        curFlashVer = super.lib.getVersion super.flashplayer;
      in if builtins.hasAttr curFlashVer flashSrcs
        then super.flashplayer.overrideAttrs (oldAttrs: rec {
          src = extractNPAPIFlash curFlashVer;
        })
        else super.flashplayer;
    flashplayer-standalone = let
        curFlashVer = super.lib.getVersion super.flashplayer-standalone;
      in if builtins.hasAttr curFlashVer flashSrcs
        then super.flashplayer-standalone.overrideAttrs (oldAttrs: rec {
          src = extractStandaloneFlash curFlashVer;
        })
        else super.flashplayer-standalone;
    # Helper so you can do e.g. `nix-prefetch-flash 30.0.0.134` to prefetch
    # and get the sha256 hash
    nix-prefetch-flash = super.writeScriptBin "nix-prefetch-flash" ''
        #!${super.dash}/bin/dash
        url="${mkFlashUrl "$1"}"
        nix-prefetch-url "$url"
      '';
  };
}
