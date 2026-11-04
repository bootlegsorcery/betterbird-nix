{
  description = "Betterbird - a fine-tuned version of Mozilla Thunderbird";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs =
    { self, nixpkgs, ... }:
    let
      supportedSystems = [
        "x86_64-linux"
        "aarch64-linux"
      ];
      forAllSystems = f: nixpkgs.lib.genAttrs supportedSystems (system: f system);

      mkBetterbird =
        pkgs:
        let
          betterbird-unwrapped = pkgs.callPackage ./betterbird.nix { };
          betterbird = pkgs.wrapThunderbird betterbird-unwrapped { libName = "betterbird"; };
        in
        {
          inherit betterbird betterbird-unwrapped;
        };
    in
    {
      packages = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          inherit (mkBetterbird pkgs) betterbird betterbird-unwrapped;
        in
        {
          inherit betterbird betterbird-unwrapped;
          default = betterbird;
        }
      );

      overlays.default = _final: prev: mkBetterbird prev;

      nixosModules.default =
        { ... }:
        {
          nixpkgs.overlays = [ self.overlays.default ];
        };
    };
}