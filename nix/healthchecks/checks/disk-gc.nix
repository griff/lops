{name, lib, rootConfig, config, pkgs, ...}:
with lib;
let
    cmd = ["${pkgs.monitoring-plugins}/bin/check_disk" "--units=${config.units}"]
        ++ (optional (config.space.warning != null) "--warning=${config.space.warning}")
        ++ (optional (config.space.critical != null) "--critical=${config.space.critical}")
        ++ (optional (config.inode.warning != null) "--iwarning=${config.inode.warning}")
        ++ (optional (config.inode.critical != null) "--icritical=${config.inode.critical}"
        ++ ["--path=${config.path}"])
    ;
    unitsConversion = {
      kB = "K";
      MB = "M";
      GB = "G";
      TB = "T";
    };
    freedUnit = unitsConversion.${config.units};
    cleanup = ["${pkgs.nix}/bin/nix-collect-garbage"]
        ++ (optional config.gc.delete-old "--delete-old")
        ++ (optionals (config.gc.delete-older-than != null) ["--delete-older-than" config.gc.delete-older-than])
        ++ (optionals (config.gc.max-freed != null) ["--max-freed" "${toString config.gc.max-freed}${freedUnit}"])
    ;
    check_cleanup = pkgs.writeScript "check_disk_cleanup" ''
        #! ${pkgs.runtimeShell}
        content="$(${escapeShellArgs cmd})"
        status=$?
        if [ $status -ne 0 ]; then
            if [ ! -f "$RUNTIME_DIRECTORY/did-cleanup" ]; then
              cleaned="$(${escapeShellArgs cleanup})"
              content="$(${escapeShellArgs cmd})"
              status=$?
              echo "$content" > "$RUNTIME_DIRECTORY/did-cleanup"
            fi
        elif [ -f "$RUNTIME_DIRECTORY/did-cleanup" ]; then
          rm "$RUNTIME_DIRECTORY/did-cleanup"
        fi
        echo $content $cleaned
        exit $status
        '';
in {
  options = {
    enable = mkOption {
      type = types.bool;
      description = "Whether to run the check.";
      default = true;
    };
    description = mkOption {
      type = types.str;
      description = "Health check description";
      default = "Disk check ${name}";
    };
    path = mkOption {
      type = types.nullOr types.str;
      description = "Only check specified path";
      default = null;
    };
    gc = {
      max-freed = mkOption {
        type = types.nullOr types.int;
        description = "Keep deleting paths until at least bytes bytes have been deleted, then stop.";
        default = null;
      };
      delete-old = mkOption {
        type = types.bool;
        description = "Deletes all old generations";
        default = false;
      };
      delete-older-than = mkOption {
        type = types.nullOr types.str;
        description = "Deletes all generations older than the specified number of days in all profiles";
        default = null;
      };
    };
    units = mkOption {
      type = types.enum ["kB" "MB" "GB" "TB"];
      default = "MB";
      description = "Unit values are in";
    };
    space = {
      warning = mkOption {
        type = types.nullOr types.str;
        default = "3000";
        description = "Exit with WARNING status if less than INTEGER units or PERCENT of disk are free";
      };
      critical = mkOption {
        type = types.nullOr types.str;
        default = "1000";
        description = "Exit with CRITICAL status if less than INTEGER units or PERCENT of disk are free";
      };
    };
    inode = {
      warning = mkOption {
        type = types.nullOr types.str;
        default = "5%";
        description = "Exit with WARNING status if less than PERCENT of inode space is free";
      };
      critical = mkOption {
        type = types.nullOr types.str;
        default = "1%";
        description = "Exit with CRITICAL status if less than PERCENT of inode space is free";
      };
    };
    receiver = mkOption {
      type = types.str;
      description = "Name of receiver to send result to";
      default = rootConfig.healthChecks.defaultReceiver;
    };
    service = mkOption {
      type = types.str;
      description = "Name for this check in the receiver";
      default = "disk_${name}";
    };
    cmd = mkOption {
      type = types.listOf types.str;
      internal = true;
    };
  };
  config.cmd = ["${check_cleanup}"];
}
