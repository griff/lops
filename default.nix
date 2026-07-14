{ sprinkles ? null }:

let
  # Load sources from `flake.lock`.
  #   flake-compat = { url = "git+https://git.lix.systems/lix-project/flake-compat?ref=main"; flake = false; };
  #   sprinkles = { url = "git+https://git.afnix.fr/sprinkles/sprinkles.git?ref=v1"; flake = false; };

  source =
    import (
      let
        lock = builtins.fromJSON (builtins.readFile ./flake.lock);
        inherit (lock.nodes.sprinkles-utils.locked) narHash rev url;
        tarball = builtins.fetchTarball {
            url = "${url}/archive/${rev}.tar.gz";
            sha256 = narHash;
          };
      in
        "${tarball}/lib/flake-sources.nix"
    ) { src = ./.; };

  input = source: {
    nixpkgs = import source.nixpkgs {
      config.allowAliases = false;
    };
    sprinkles = if sprinkles == null
      then import source.sprinkles
      else sprinkles;
  };
in
(input source).sprinkles.new {
  inherit input source;

  output = self: {
    nixosModules.deployment = import ./nix/deployment.nix;
    nixosModules.healthchecks = import ./nix/healthchecks;
    lib.hive = import ./nix/hive.nix;
    overlays.default = import ./overlay.nix;
    packages.check-health = self.input.nixpkgs.callPackage ./check-health.nix {};
    packages.lops = self.input.nixpkgs.callPackage ./lops.nix {
        inherit (self.output.packages) check-health;
      };
    packages.default = self.output.packages.lops;
  };
}