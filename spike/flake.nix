# ⚠️ UNTESTED DESIGN DRAFT — Nix is not installed on the dev machine yet.
# This is a starting point to iterate on, NOT a working build. It encodes the
# *shape* of the tail spike (see ../docs/NIX-LAYER.md §6): prove that
#   CoreFn  ──(pinned psgo + pinned go)──▶  reproducible Go binary
# is hermetic. The FRONT (PS → CoreFn, via spago's impure registry fetch) is
# deferred — for the spike, point `corefn` at a pre-built / vendored CoreFn dir.
#
# What to validate when Nix lands:
#   nix build .#hello-go      # should realise a content-addressed go binary
#   nix-store --realise ...   # the §8.3 "delegate the back" assumption
{
  description = "Tail spike: CoreFn -> reproducible Go binary (psgo + go pinned)";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = { self, nixpkgs }:
    let
      system = "aarch64-darwin";
      pkgs = import nixpkgs { inherit system; };

      # psgo enters Nix as a FIXED-OUTPUT derivation wrapping the prebuilt
      # binary (trusts provenance; fine for the spike). Replace `src`/`hash`
      # with the real path + sha256 (nix-prefetch). Full hermeticity later via
      # haskell.nix if it earns its weight.
      psgo = pkgs.stdenvNoCC.mkDerivation {
        name = "psgo-prebuilt";
        # e.g. /Users/afc/.../purescript-go/.stack-work/install/.../bin/psgo
        src = builtins.fetchClosure { };   # <-- TODO: real fixed-output input
        dontUnpack = true;
        installPhase = "install -Dm755 $src $out/bin/psgo";
      };

      # The CoreFn front, vendored for the spike (output of `spago build` with
      # backend.cmd "true"). TODO: replace with a derivation once the front is
      # made hermetic (pre-fetched package set à la purs-nix/spago2nix).
      corefn = ./vendored-corefn;            # <-- TODO: a real CoreFn output/ dir

      # The co-located Go foreign (resolved by psgo via modulePath in real runs;
      # here we hand it the seam file directly).
      runtimeForeign = ../examples/runtime-name/core/src/Runtime.go;
    in {
      packages.${system}.hello-go = pkgs.stdenv.mkDerivation {
        name = "hello-go";
        nativeBuildInputs = [ psgo pkgs.go ];
        dontUnpack = true;
        buildPhase = ''
          cp -r ${corefn} output && chmod -R +w output
          psgo output output-go --entry Main
          cp ${runtimeForeign} output-go/Runtime_foreign.go   # if not already co-located
          ( cd output-go && go build -o hello-go ./*.go )
        '';
        installPhase = "install -Dm755 output-go/hello-go $out/bin/hello-go";
        # GOFLAGS/GOPROXY off => no network; the closure is psgo + go + corefn.
        GOFLAGS = "-mod=mod";
        GOPROXY = "off";
      };
    };
}
