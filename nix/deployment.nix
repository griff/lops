{ config, lib, pkgs, ... }:

with lib;
with lib.types;

{
  options.deployment = {

    targetHost = mkOption {
      type = str;
      default = "";
      description = ''
        The remote host used for deployment. If this is not set it will fallback to the deployments attribute name.
      '';
    };

    targetUser = mkOption {
      type = str;
      default = "";
      description = ''
        The remote user used for deployment. If this is not set it will fallback to the user specified in the
        <literal>SSH_USER</literal> environment variable or use the current local user as a last resort.
      '';
    };

    buildOnly = mkOption {
      type = bool;
      default = false;
      description = ''
        Set to true if the host will not be real or reachable.
        This is useful for system configs used to build iso's, local testing etc.
        Will make the following features unavailable for the host:
          push, deploy, check-health, upload-secrets, exec
      '';
    };

    substituteOnDestination = mkOption {
      type = bool;
      default = false;
      description = ''
        Sets the `--substitute-on-destination` flag on nix copy,
        allowing for the deployment target to use substitutes.
        See `nix copy --help`.
      '';
    };

    tags = mkOption {
      type = listOf str;
      default = [];
      description = ''
        Host tags.
      '';
    };
  };
}
