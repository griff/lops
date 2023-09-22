{name, lib, rootConfig, ...}:
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
      default = "Cmd check ${name}";
    };
    receiver = mkOption {
      type = types.str;
      description = "Name of receiver to send result to";
      default = rootConfig.healthChecks.defaultReceiver;
    };
    service = mkOption {
      type = types.str;
      description = "Name for this check in the receiver";
      default = "cmd_${name}";
    };
    cmd = mkOption {
      type = types.listOf types.str;
      description = "Command to execute for the check";
    };
  };
}
