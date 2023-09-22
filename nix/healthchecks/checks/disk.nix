{name, lib, rootConfig, config, pkgs, ...}:
with lib;
{
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
    all = mkOption {
      type = types.bool;
      description = "Explicitly select all paths.";
      default = false;
    };
    ignoreRegexPaths = mkOption {
      type = types.listOf types.str;
      default = [];
      description = "Regular expression to ignore selected paths";
    };
    regexPaths = mkOption {
      type = types.listOf types.str;
      default = [];
      description = "Regular expression for path";
    };
    includeTypes = mkOption {
      type = types.listOf types.str;
      default = [];
      description = "Check only filesystems of indicated types";
    };
    excludeTypes = mkOption {
      type = types.listOf types.str;
      default = [];
      description = "Ignore all filesystems of indicated type";
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
  config.cmd = ["${pkgs.monitoring-plugins}/bin/check_disk" "--units=${config.units}"]
    ++ (optional (config.space.warning != null) "--warning=${config.space.warning}")
    ++ (optional (config.space.critical != null) "--critical=${config.space.critical}")
    ++ (optional (config.inode.warning != null) "--iwarning=${config.inode.warning}")
    ++ (optional (config.inode.critical != null) "--icritical=${config.inode.critical}")
    ++ (optional (config.path != null) "--path=${config.path}")
    ++ (optional config.all "--all")
    ++ (map (v: "--ereg-path=${v}") config.regexPaths)
    ++ (map (v: "--ignore-ereg-path=${v}") config.ignoreRegexPaths)
    ++ (map (v: "--exclude-type=${v}") config.excludeTypes)
    ++ (map (v: "--include-type=${v}") config.includeTypes)
;
}
