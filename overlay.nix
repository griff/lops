self: super: {
  lops = self.callPackage ./lops.nix {};
  check-health = super.callPackage ./check-health.nix {};
}