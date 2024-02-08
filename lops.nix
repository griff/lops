{stdenv, lib, ruby, openssh, nix, check-health}:
stdenv.mkDerivation {
  name = "lops";
  src = ./.;
  buildInputs = [ ruby ];
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
  path = lib.makeBinPath [ openssh nix check-health ];
}