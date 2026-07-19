{
  description = "A very basic flake";
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";
    sprinkles = { url = "git+https://git.afnix.fr/sprinkles/sprinkles.git?ref=v1"; flake = false; };
    dried-nix-flakes.url = "github:cyberus-technology/dried-nix-flakes";
    sprinkles-utils = { url = "git+https://codeberg.org/griff79/sprinkles-utils?ref=main"; flake = false; };
  };

  outputs =
    inputs:
    inputs.dried-nix-flakes inputs (
      { nixpkgs, import, ... }:
      ((import ./default.nix).override { input = _: { nixpkgs = nixpkgs.legacyPackages; }; }).output
    );
  /*
  outputs = { self, flake-utils, nixpkgs, ... }: {
    nixosModules.deployment = import ./nix/deployment.nix;
    nixosModules.healthchecks = import ./nix/healthchecks;
    lib.hive = import ./nix/hive.nix;
    overlays.default = import ./overlay.nix;
  } // (flake-utils.lib.eachDefaultSystem (system: let
      pkgs = nixpkgs.legacyPackages.${system};
      check-health = pkgs.callPackage ./check-health.nix {};
      lops = pkgs.callPackage ./lops.nix {
        inherit check-health;
      };
    in {
    packages.check-health = check-health;
    packages.lops = lops;
    packages.default = lops;
  }));
  */
}
