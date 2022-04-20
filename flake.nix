{
    outputs = { nixpkgs, ... }: {
        default = builtins.mapAttrs (k: v: import ./. { pkgs = v; }) nixpkgs.legacyPackages;

    };
}
