let
  bootstrap = import ./nix/bootstrap.nix;
in
bootstrap.new (self: {
  sources =
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
  inputs = {
    nixpkgs = import self.sources.nixpkgs {
      config.allowAliases = false;
    };
  };

  output = {
    nixosModules.default = with self.output.nixosModules; { imports = [deployment healthchecks]; };
    nixosModules.deployment = import ./nix/deployment.nix;
    nixosModules.healthchecks = import ./nix/healthchecks;
    lib.hive = import ./nix/hive.nix;
    overlays.default = import ./overlay.nix;
    packages.check-health = self.inputs.nixpkgs.callPackage ./check-health.nix {};
    packages.lops = self.inputs.nixpkgs.callPackage ./lops.nix {
        inherit (self.output.packages) check-health;
      };
    packages.default = self.output.packages.lops;
  };
})