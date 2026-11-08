# betterbird-nix

A Nix flake to package and run the official [Betterbird](https://www.betterbird.eu/) Linux archive on NixOS.

Betterbird was previously available in nixpkgs but was [removed in PR #351205](https://github.com/NixOS/nixpkgs/pull/351205)
due to insufficient maintainer resources. This flake reimplements it.

On that note, this is a best effort repository which I'm making for personal use. Please don't expect quick fixes or timely updates.

## Usage

### Run directly

```sh
nix run github:bootlegsorcery/betterbird-nix
```

### Build

```sh
nix build github:bootlegsorcery/betterbird-nix
./result/bin/betterbird
```

### Add to your NixOS configuration

Add the flake to your inputs:

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    betterbird-nix.url = "github:bootlegsorcery/betterbird-nix";
  };

  outputs = inputs@{ self, nixpkgs, betterbird-nix, ... }: {
    nixosConfigurations.myhost = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      specialArgs = { inherit inputs; };
      modules = [ ./configuration.nix ];
    };
  };
}
```

Then install it:

```nix
environment.systemPackages = [
  inputs.betterbird-nix.packages.${pkgs.stdenv.hostPlatform.system}.default
];
```

Installing the package output directly keeps Betterbird pinned to this flake's
nixpkgs input, so updating the host's nixpkgs does not recreate the package.

### Use as an overlay

```nix
nixpkgs.overlays = [ betterbird-nix.overlays.default ];
environment.systemPackages = [ pkgs.betterbird ];
```

## Updating

To update Betterbird to a new version:

1. Find the current x86_64 and aarch64 archives on the
   [Betterbird downloads page](https://www.betterbird.eu/downloads/).
2. Update `version` and both archive URLs in `betterbird.nix`.
3. Fetch each archive and copy its SRI hash into `betterbird.nix`:
   ```sh
   nix store prefetch-file --json URL
   ```
4. Run `nix build .#betterbird` and `nix run .#betterbird -- --version` to verify.

## How it works

The flake fetches Betterbird's official architecture-specific archive, patches
its ELF interpreter and library paths for NixOS, then uses `wrapThunderbird` for
desktop, GTK, and GPG integration. It does not compile Thunderbird from source.
