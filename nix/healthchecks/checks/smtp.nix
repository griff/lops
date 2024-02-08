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
      default = "SMTP check ${name}";
    };
    hostname = mkOption {
      type = types.str;
      description = "Hostname to perform SMTP check against";
    };
    port = mkOption {
      type = types.int;
      default = 25;
      description = "Port to use for SMTP check";
    };
    certificateCheck = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "Enable certificate check";
      };
      warningDays = mkOption {
        type = types.int;
        description = "Days before expiration to warn";
        default = 20;
      };
      criticalDays = mkOption {
        type = types.int;
        description = "Days before expiration for critical";
        default = 10;
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
      default = "smtp_${name}";
    };
    cmd = mkOption {
      type = types.listOf types.str;
      internal = true;
    };
  };
  config.cmd = [
    "${pkgs.monitoring-plugins}/bin/check_smtp"
    "-t" "60"
    "-H" config.hostname
    "-p" "${toString config.port}"
  ] ++ (with config.certificateCheck; optionals enable [
    "-S" "-D" "${toString warningDays},${toString criticalDays}"
  ]);
}
