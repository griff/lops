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
  } // (flake-utils.lib.eachDefaultSystem (system: let
      pkgs = nixpkgs.legacyPackages.${system};
    in {
    packages.check-health = pkgs.stdenv.mkDerivation {
      name = "check-health";
      src = ./bin/check-health.rb;
      buildInputs = [ pkgs.ruby ];
      dontUnpack = true;
      buildPhase = "true";
      installPhase = ''
        mkdir -p "$out/bin"
        cp $src "$out/bin/check-health"
        substituteAllInPlace "$out/bin/check-health"
        chmod a+x "$out/bin/check-health"
      '';
    };
    packages.lops = nixpkgs.legacyPackages.${system}.stdenv.mkDerivation {
      name = "lops";
      src = ./.;
      buildInputs = [ pkgs.ruby ];
      dontUnpack = true;
      buildPhase = "true";
      installPhase = ''
        mkdir -p "$out/bin"
        cp $src/bin/lops.rb "$out/bin/lops"
        substituteAllInPlace "$out/bin/lops"
        chmod a+x "$out/bin/lops"
        mkdir -p "$out/libexec"
        for k in $src/bin/lops-*.rb ; do
          name="$(basename "$k" .rb)"
          cp $k "$out/libexec/$name"
          substituteAllInPlace "$out/libexec/$name"
          chmod a+x "$out/libexec/$name"
        done
        mkdir -p "$out/share/lops"
        cp -r $src/lib "$out/share/lops/"

      '';
      path = with pkgs; lib.makeBinPath [ openssh nix self.packages.${system}.check-health ];
    };
    packages.default = self.packages.${system}.lops;
  }));
}
