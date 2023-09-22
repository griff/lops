{name, config, lib, pkgs, ...}:
with lib;
let
  cfg = config.healthChecks;
  receiverModule = {name, ...}:{
    options = {
      tokenFile = mkOption {
        type = types.str;
        description = "File containing token to use for NRDP";
      };
      server = mkOption {
        type = types.str;
        description = "Server to send NRDP to";
      };
      timerConfig = mkOption {
        type = types.attrsOf types.str;
        default = {
          OnCalendar = "*:00/5:00";
          RandomizedDelaySec = "120s";
        };
        description = ''
          When to run the health check. See man systemd.timer for details.
        '';
        example = {
          OnCalendar = "00:05";
          RandomizedDelaySec = "5h";
        };
      };
      hostName = mkOption {
        type = types.str;
        description = "Hostname to use when sending status";
        default = config.networking.hostName;
      };
    };
  };

  normalize = prefix: state: values:
    flip mapAttrs' (filterAttrs (n: v: v.enable) values) (n: v: let
        receiver = cfg.receivers.${v.receiver};
      in
        nameValuePair ("healthchecks-${prefix}_${n}") {
          timerConfig = receiver.timerConfig;
          state = state;
          script = ''
            TOKEN="$(cat ${receiver.tokenFile})"
            set +e
            content="$(${escapeShellArgs v.cmd})"
            status=$?
            echo -e "${receiver.hostName}\t${v.service}\t$status\t$content" | ${pkgs.send_nrdp}/bin/send_nrdp \
              -u ${receiver.server} \
              -t $TOKEN
          '';
        });
  allChecks = (normalize "smtp" false cfg.checks.smtp)
    // (normalize "disk" false cfg.checks.disk)
    // (normalize "disk-gc" true cfg.checks.disk-gc)
    // (normalize "cmd" false cfg.checks.cmd)
    // (normalize "systemd" false { "failed" = cfg.checks.systemd-failed; })
    // (normalize "oom" false { "killer" = cfg.checks.oom-killer; });
  importCheck = path: [(import path) {
    _module.args.rootConfig = config;
    _module.args.pkgs = pkgs;
  }];
  mapCheck = items: flip mapAttrsToList (filterAttrs (n: v: v.enable) items) (n: v: {
    description = v.description;
    cmd = v.cmd;
    timeout = 10;
  });
  checkCmd = (mapCheck cfg.checks.smtp)
        ++ (mapCheck cfg.checks.cmd)
        ++ (mapCheck cfg.checks.disk)
        ++ (mapCheck cfg.checks.disk-gc)
        ++ (mapCheck {systemd-failed = cfg.checks.systemd-failed;});
  healthChecksJSON = pkgs.writeText "health-checks.json"
    (builtins.toJSON { host = name; http = []; cmd = checkCmd; });
in {
  options.healthChecks = {
    enable = mkEnableOption "Enable health checks";
    defaultReceiver = mkOption {
      type = types.str;
      default = head (attrNames config.healthChecks.receivers);
      description = "The default receiver of health checks";
    };
    receivers = mkOption {
      type = types.attrsOf (types.submodule receiverModule);
      default = {};
      description = "Receivers of health checks";
    };
    checks.smtp = mkOption {
      type = types.attrsOf (types.submodule (importCheck ./checks/smtp.nix));
      default = {};
      description = "SMTP health checks";
    };
    checks.disk = mkOption {
      type = types.attrsOf (types.submodule (importCheck ./checks/disk.nix));
      default = {};
      description = "Disk health checks";
    };
    checks.disk-gc = mkOption {
      type = types.attrsOf (types.submodule (importCheck ./checks/disk-gc.nix));
      default = {};
      description = "Disk health checks with Nix GC";
    };
    checks.cmd = mkOption {
      type = types.attrsOf (types.submodule (importCheck ./checks/cmd.nix));
      default = {};
      description = "Command line health checks";
    };
    checks.systemd-failed = {
      enable = mkOption {
        type = types.bool;
        description = "Whether to run the check for SystemD failed units.";
        default = true;
      };
      description = mkOption {
        type = types.str;
        description = "Health check description";
        default = "No Systemd Failed units";
      };
      receiver = mkOption {
        type = types.str;
        description = "Name of receiver to send result to";
        default = cfg.defaultReceiver;
      };
      service = mkOption {
        type = types.str;
        description = "Name for this check in the receiver";
        default = "systemd-failed";
      };
      cmd = mkOption {
        type = types.listOf types.str;
        internal = true;
        default = ["${pkgs.check_systemd}/bin/check_systemd_failed"];
      };
    };
    checks.oom-killer = {
      enable = mkOption {
        type = types.bool;
        description = "Whether to run the check for processes killed by OOM.";
        default = true;
      };
      description = mkOption {
        type = types.str;
        description = "Health check description";
        default = "No processes killed by OOM killer";
      };
      receiver = mkOption {
        type = types.str;
        description = "Name of receiver to send result to";
        default = cfg.defaultReceiver;
      };
      service = mkOption {
        type = types.str;
        description = "Name for this check in the receiver";
        default = "oom-killer";
      };
      cmd = mkOption {
        type = types.listOf types.str;
        internal = true;
        default = ["${pkgs.check_systemd}/bin/check_oomkiller" "systemd-check"];
      };
    };
  };
  config = mkIf cfg.enable {
    environment.systemPackages = with pkgs; [ monitoring-plugins check_systemd send_nrdp ];

    systemd.timers = flip mapAttrs allChecks (n: v: {
      wantedBy = ["multi-user.target"];
      timerConfig = v.timerConfig;
    });
    systemd.services = flip mapAttrs allChecks (n: v: {
      script = v.script;
      serviceConfig.Type = "oneshot";
      serviceConfig.RuntimeDirectory = mkIf v.state n;
      serviceConfig.RuntimeDirectoryPreserve = mkIf v.state true;
    });
    system.extraSystemBuilderCmds = ''
      ln -s "${healthChecksJSON}" $out/health-checks.json
    '';
  };
}
