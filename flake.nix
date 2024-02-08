{
  description = "A very basic flake";
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-23.05";
    flake-utils.url = "github:numtide/flake-utils";
    #nix-filter.url = "github:numtide/nix-filter";
  };

  outputs = { self, flake-utils, nixpkgs, ... }: {
    nixosModules.deployment = import ./nix/deployment.nix;
    nixosModules.healthchecks = import ./nix/healthchecks;
    lib.hive = import ./nix/hive.nix { inherit flake-utils nixpkgs; };
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
    packages.default = self.packages.${system}.lops;
  }));
}
