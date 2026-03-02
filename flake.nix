# vim: filetype=nix: tabstop=3: shiftwidth=3: noexpandtab:
{
  description = "Tartube mínimo (sin moviepy/arrow) usando nixpkgs-unstable";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

  outputs = { self, nixpkgs }:
  let
    system = "x86_64-darwin";
    pkgs = import nixpkgs {
      inherit system;
      overlays = [
        (final: prev: {
          tartube = prev.tartube.overridePythonAttrs (old: {
            propagatedBuildInputs =
              builtins.filter (p: (p.pname or "") != "moviepy")
                (old.propagatedBuildInputs or []);
          });
        })
      ];
    };
  in {
    packages.${system}.default = pkgs.symlinkJoin {
      name = "tartube-min-bundle";
      paths = [ pkgs.tartube pkgs.yt-dlp pkgs.ffmpeg ];
    };
  };
}

