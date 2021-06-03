nixpkgs:
let

  #
  # The fetchers. fetch_<type> fetches specs of type <type>.
  #

  fetch_file = pkgs: name: spec:
    let
      name' = sanitizeName name + "-src";
    in
      if spec.builtin or true then
        builtins_fetchurl { inherit (spec) url sha256; name = name'; }
      else
        pkgs.fetchurl { inherit (spec) url sha256; name = name'; };

  fetch_tarball = pkgs: name: spec:
    let
      name' = sanitizeName name + "-src";
    in
      if spec.builtin or true then
        builtins_fetchTarball { name = name'; inherit (spec) url sha256; }
      else
        pkgs.fetchzip { name = name'; inherit (spec) url sha256; };

  fetch_git = name: spec:
    let
      ref =
        if spec ? ref then spec.ref else
          if spec ? branch then "refs/heads/${spec.branch}" else
            if spec ? tag then "refs/tags/${spec.tag}" else
              abort "In git source '${name}': Please specify `ref`, `tag` or `branch`!";
    in
      builtins.fetchGit { url = spec.repo; inherit (spec) rev; inherit ref; };

  fetch_local = spec: spec.path;

  fetch_builtin-tarball = name: throw
    ''[${name}] The niv type "builtin-tarball" is deprecated. You should instead use `builtin = true`.
        $ niv modify ${name} -a type=tarball -a builtin=true'';

  fetch_builtin-url = name: throw
    ''[${name}] The niv type "builtin-url" will soon be deprecated. You should instead use `builtin = true`.
        $ niv modify ${name} -a type=file -a builtin=true'';

  #
  # Various helpers
  #

  # https://github.com/NixOS/nixpkgs/pull/83241/files#diff-c6f540a4f3bfa4b0e8b6bafd4cd54e8bR695
  sanitizeName = name:
    (
      concatMapStrings (s: if builtins.isList s then "-" else s)
        (
          builtins.split "[^[:alnum:]+._?=-]+"
            ((x: builtins.elemAt (builtins.match "\\.*(.*)" x) 0) name)
        )
    );

  # The set of packages used when specs are fetched using non-builtins.
  mkPkgs = sources: system: import nixpkgs { inherit system; };

  # The actual fetching function.
  fetch = pkgs: name: spec:

    if ! builtins.hasAttr "type" spec then
      abort "ERROR: niv spec ${name} does not have a 'type' attribute"
    else if spec.type == "file" then fetch_file pkgs name spec
    else if spec.type == "tarball" then fetch_tarball pkgs name spec
    else if spec.type == "git" then fetch_git name spec
    else if spec.type == "local" then fetch_local spec
    else if spec.type == "builtin-tarball" then fetch_builtin-tarball name
    else if spec.type == "builtin-url" then fetch_builtin-url name
    else
      abort "ERROR: niv spec ${name} has unknown type ${builtins.toJSON spec.type}";

  # If the environment variable NIV_OVERRIDE_${name} is set, then use
  # the path directly as opposed to the fetched source.
  replace = name: drv:
    let
      saneName = stringAsChars (c: if isNull (builtins.match "[a-zA-Z0-9]" c) then "_" else c) name;
      ersatz = builtins.getEnv "NIV_OVERRIDE_${saneName}";
    in
      if ersatz == "" then drv else
        # this turns the string into an actual Nix path (for both absolute and
        # relative paths)
        if builtins.substring 0 1 ersatz == "/" then /. + ersatz else /. + builtins.getEnv "PWD" + "/${ersatz}";

  # Ports of functions for older nix versions

  # a Nix version of mapAttrs if the built-in doesn't exist
  mapAttrs = builtins.mapAttrs or (
    f: set: with builtins;
    listToAttrs (map (attr: { name = attr; value = f attr set.${attr}; }) (attrNames set))
  );

  # https://github.com/NixOS/nixpkgs/blob/0258808f5744ca980b9a1f24fe0b1e6f0fecee9c/lib/lists.nix#L295
  range = first: last: if first > last then [] else builtins.genList (n: first + n) (last - first + 1);

  # https://github.com/NixOS/nixpkgs/blob/0258808f5744ca980b9a1f24fe0b1e6f0fecee9c/lib/strings.nix#L257
  stringToCharacters = s: map (p: builtins.substring p 1 s) (range 0 (builtins.stringLength s - 1));

  # https://github.com/NixOS/nixpkgs/blob/0258808f5744ca980b9a1f24fe0b1e6f0fecee9c/lib/strings.nix#L269
  stringAsChars = f: s: concatStrings (map f (stringToCharacters s));
  concatMapStrings = f: list: concatStrings (map f list);
  concatStrings = builtins.concatStringsSep "";

  # https://github.com/NixOS/nixpkgs/blob/8a9f58a375c401b96da862d969f66429def1d118/lib/attrsets.nix#L331
  optionalAttrs = cond: as: if cond then as else {};

  # fetchTarball version that is compatible between all the versions of Nix
  builtins_fetchTarball = { url, name ? null, sha256 }@attrs:
    let
      inherit (builtins) lessThan nixVersion fetchTarball;
    in
      if lessThan nixVersion "1.12" then
        fetchTarball ({ inherit url; } // (optionalAttrs (!isNull name) { inherit name; }))
      else
        fetchTarball attrs;

  # fetchurl version that is compatible between all the versions of Nix
  builtins_fetchurl = { url, name ? null, sha256 }@attrs:
    let
      inherit (builtins) lessThan nixVersion fetchurl;
    in
      if lessThan nixVersion "1.12" then
        fetchurl ({ inherit url; } // (optionalAttrs (!isNull name) { inherit name; }))
      else
        fetchurl attrs;

  # Create the final "sources" from the config
  mkSources = config:
    mapAttrs (
      name: spec:
        if builtins.hasAttr "outPath" spec
        then abort
          "The values in sources.json should not have an 'outPath' attribute"
        else
          spec // { outPath = replace name (fetch config.pkgs name spec); }
    ) config.sources;

  # The "config" used by the fetchers
  mkConfig =
    { sourcesFile ? if builtins.pathExists ./sources.json then ./sources.json else null
    , sources ? if isNull sourcesFile then {} else builtins.fromJSON (builtins.readFile sourcesFile)
    , system ? builtins.currentSystem
    , pkgs ? mkPkgs sources system
    }: rec {
      # The sources, i.e. the attribute set of spec name to spec
      inherit sources;

      # The "pkgs" (evaluated nixpkgs) to use for e.g. non-builtin fetchers
      inherit pkgs;
    };

in
mkSources (mkConfig {}) // { __functor = _: settings: mkSources (mkConfig settings); }
