{ pkgs ? import <nixpkgs> { }, ... }: rec {
  appendDerivation = f: f // {
    __functor = self: arg: pkgs.runCommand "${f.pname}/S" self arg;
  };

  overlayfs = "${pkgs.fuse-overlayfs}/bin/fuse-overlayfs";

  runList = parent: command: pkgs.runCommand "command-list"
    {
      # __functor = self: nextCommand: (if nextCommand == null then self else (runList self nextCommand));
      passthru = { inherit parent command; };
      buildInputs = [ pkgs.fuse-overlayfs pkgs.fuse3 ];
    } ''
    ${restoreEnv parent}
    ${startEnv}
    ${command}
    ${saveEnv}
  '';

  collectLayers = layer: if layer == null then [ ] else ((collectLayers layer.passthru.parent) ++ [ layer ]);

  dockerlike = { first ? null, list }:
    if list == [ ]
    then first
    else dockerlike { first = runList first (builtins.head list); list = builtins.tail list; };

  # startList = pkgs.runCommand "command-name"
  #   { }
  #   ''
  #     ${startEnv}
  #     ${saveEnv}
  #   '';

  testList = dockerlike
    {
      list = [
        "ls -hal $out"
        "ls -hal > $out/test"
        "export a=12"
        "export b=42"
        "echo $((a + b)) > $out/test2"
        "ls -hal $out"
      ];
    };

  system = "x86_64-linux";

  startEnv =
    ''
      env | sort > $TMP/.startenv
    '';

  saveEnv = ''
    # ${pkgs.fuse}/bin/fusermount -u $out
    # mv $TMP/.layer $out/layer
    env | sort | comm - $TMP/.startenv -23 >> $out/.envdiff
  '';



  restoreEnv = from:
    let
      layers = with builtins; trace "mowmow layers ${toString (collectLayers from)}" collectLayers from;
      lowerdirs = with builtins; concatStringsSep ":" (map (f: "${f}/layer") layers);
    in
    ''
      mkdir -p $out
      mkdir $TMP/.workdir
      mkdir $out/layer

      ${if layers != [] then ''
        echo ${overlayfs} -o auto_unmount,lowerdir=${lowerdirs},workdir=$TMP/.workdir,upperdir=$TMP/.layer $out
        ${overlayfs} -o lowerdir=${lowerdirs},workdir=$TMP/.workdir,upperdir=$out/layer $out
      '' else ""}
      ${if from != null then ''source ${from}/.envdiff'' else ""}
    '';

  runScript = { shell ? "/bin/sh", script, name ? "script", extra ? { } }: derivation
    {
      inherit name system;
      builder = shell;
      args = [
        (builtins.toFile "builder-${name}.sh" script)
      ];
    } // extra;

  runShScript = runScript {
    name = "asdf";
    script = ''
      export PATH=$PATH:${pkgs.coreutils}
      touch test
    '';
    extra = {
      buildInputs = [ pkgs.coreutils ];
    };
  };



}
