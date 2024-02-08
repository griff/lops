{ stdenv, ruby }:
stdenv.mkDerivation {
  name = "check-health";
  src = ./bin/check-health.rb;
  buildInputs = [ ruby ];
  dontUnpack = true;
  buildPhase = "true";
  installPhase = ''
    mkdir -p "$out/bin"
    cp $src "$out/bin/check-health"
    substituteAllInPlace "$out/bin/check-health"
    chmod a+x "$out/bin/check-health"
  '';
}