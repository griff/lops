{ nixpkgs, flake-utils }:
{ nodes, template ? ./.template }:
with nixpkgs;
rec {
  inherit nodes;
  toplevel =         lib.mapAttrs (_: v: v.config.system.build.toplevel) nodes;
  deploymentConfig = lib.mapAttrs (_: v: v.config.deployment)            nodes;
  evalSelected =         names: lib.filterAttrs (name: _: builtins.elem name names) toplevel;
  evalSelectedDrvPaths = names: lib.mapAttrs    (_: v: v.drvPath)          (evalSelected names);
  allMachines = machines:
    flake-utils.lib.eachDefaultSystemMap (system:
      let
        pkgs = legacyPackages.${system};
        info = lib.mapAttrs (_: node:
            pkgs.writeText "info.json" (builtins.toJSON node)
          ) deploymentConfig;
        all-info = pkgs.writeText "info.json" (
          builtins.toJSON
          (lib.getAttrs (lib.attrNames machines) deploymentConfig));
      in pkgs.runCommand "all-machines" {} ''
        mkdir -p "$out"
        ln -s ${all-info} "$out/info.json"
        ${lib.concatMapStringsSep "\n" (n: ''
          mkdir -p "$out/${n}"
          ln -s ${info.${n}} "$out/${n}/info.json"
          ln -s ${machines.${n}} "$out/${n}/system"
        '') (lib.attrNames machines)}
      ''
    );
  importMachines = machines: let
    imported = lib.mapAttrs (_: v: import v) machines;
    in allMachines imported;
}