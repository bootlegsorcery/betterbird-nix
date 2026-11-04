# betterbird-nix

A Nix flake to build and run [Betterbird](https://www.betterbird.eu/) on NixOS.

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

  outputs = { self, nixpkgs, betterbird-nix, ... }: {
    nixosConfigurations.myhost = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        betterbird-nix.nixosModules.default
        ./configuration.nix
      ];
    };
  };
}
```

Then install it:

```nix
environment.systemPackages = [ pkgs.betterbird ];
```

### Use as an overlay

```nix
nixpkgs.overlays = [ betterbird-nix.overlays.default ];
environment.systemPackages = [ pkgs.betterbird ];
```

## Updating

To update Betterbird to a new version:

1. Check the [thunderbird-patches repo](https://github.com/Betterbird/thunderbird-patches/tags)
   for the latest release tag (e.g. `153.7.0esr-bb13`).
2. Update `version` and the tag (`rev`) in `betterbird.nix`.
3. Update the source hash. Use the **candidate** tarball URL (not the release
   tarball), since Betterbird patches are built against the candidate:
   ```sh
   nix-prefetch-url --type sha512 "https://archive.mozilla.org/pub/thunderbird/candidates/NEW_VERSION-candidates/build1/source/thunderbird-NEW_VERSION.source.tar.xz"
   ```
   The candidate URL can be found in
   `metadata/eu.betterbird.Betterbird.MAJOR.appdata.xml` in the thunderbird-patches
   repo. Convert with `nix hash convert --hash-algo sha512 --to sri HASH`.
4. Update the patches hash:
   ```sh
   nix-prefetch-url --type sha256 --unpack "https://github.com/Betterbird/thunderbird-patches/archive/TAG.tar.gz"
   ```
   Convert with `nix hash convert --hash-algo sha256 --to sri HASH`.
5. Run `nix build .#betterbird` to verify.

## Build resource requirements

Building Betterbird compiles Thunderbird from source using `buildMozillaMach`,
which enables [Link-Time Optimization](https://llvm.org/docs/LinkTimeOptimization.html)
(LTO) by default. Each parallel `clang++` process can use 2-5 GB of RAM, so
with unbounded parallelism (the Nix default when `cores = 0`) the build can
easily exhaust available RAM and cause the system to hang from swap thrashing.

To avoid this, limit parallelism when building:

```sh
nix build .#betterbird --cores 4 --max-jobs 1
```

Adjust `--cores` based on your available RAM (roughly 4-5 GB per core).
Alternatively, set [`nix.settings.cores`](https://search.nixos.org/options?query=nix.cores)
in your NixOS configuration.

## How it works

The flake builds Betterbird by:
1. Fetching the Thunderbird ESR source tarball from Mozilla.
2. Fetching the Betterbird patches from the
   [thunderbird-patches](https://github.com/Betterbird/thunderbird-patches) repo.
3. Applying the patches using `git apply` in the `extraPostPatch` phase.
4. Building with nixpkgs' `buildMozillaMach` (the same builder used for Thunderbird).
5. Wrapping with `wrapThunderbird` for desktop integration and GPG support.
