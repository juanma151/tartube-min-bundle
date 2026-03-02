# vim: filetype=nix: tabstop=3: shiftwidth=3: noexpandtab:
{
  description = "Tartube mínimo (sin moviepy) + yt-dlp + bundle macOS (.app) con icono";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

  outputs = { self, nixpkgs }:
  let
    system = "x86_64-darwin";
    pkgs = import nixpkgs {
      inherit system;
      overlays = [
        (final: prev: {
          # Tartube con:
          # - youtube-dl -> yt-dlp (por el makeWrapperArgs del paquete nixpkgs)
          # - moviepy fuera (para reducir deps)
          tartube =
            (prev.tartube.override {
              youtube-dl = final.yt-dlp;
            }).overridePythonAttrs (old: {
              propagatedBuildInputs =
                builtins.filter (p: (p.pname or "") != "moviepy")
                  (old.propagatedBuildInputs or []);
            });

          # Bundle macOS: result/Applications/Tartube.app
          tartubeApp = final.stdenvNoCC.mkDerivation {
            pname = "tartube-macwrapp";
            version = final.tartube.version or "unknown";

            # aquí tienes tu icono:
            #   ./src/tartube.icns
            src = ./src;
            dontUnpack = true;

            installPhase = ''
              set -euo pipefail

              app="$out/Applications/Tartube.app"
              mkdir -p "$app/Contents/"{MacOS,Resources}

              # Info.plist con icono
              cat > "$app/Contents/Info.plist" <<PLIST
              <?xml version="1.0" encoding="UTF-8"?>
              <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
                "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
              <plist version="1.0">
              <dict>
                <key>CFBundleName</key>
                <string>tartube</string>

                <key>CFBundleDisplayName</key>
                <string>tartube</string>

                <key>CFBundleIdentifier</key>
                <string>io.nixos.tartube</string>

                <key>CFBundleVersion</key>
                <string>${final.tartube.version or "0"}</string>

                <key>CFBundleShortVersionString</key>
                <string>${final.tartube.version or "0"}</string>

                <key>CFBundlePackageType</key>
                <string>APPL</string>

                <key>CFBundleExecutable</key>
                <string>tartube</string>

                <key>CFBundleIconFile</key>
                <string>tartube</string>

                <key>LSMinimumSystemVersion</key>
                <string>10.13</string>

                <key>NSHighResolutionCapable</key>
                <true/>
              </dict>
              </plist>
              PLIST

              # Copiar icono (sin .icns en CFBundleIconFile)
              cp "$src/tartube.icns" "$app/Contents/Resources/tartube.icns"

              # Launcher: ejecuta el tartube del Nix store
              cat > "$app/Contents/MacOS/tartube" <<'SH'
              #!/usr/bin/env bash
              set -euo pipefail

              # Por si lo lanzas fuera de un entorno con PATH "bonito":
              export PATH="@PATH@:$PATH"

              exec "@TARTUBE@/bin/tartube" "$@"
              SH

              # Sustituciones (evita interpolación Nix dentro del heredoc)
              substituteInPlace "$app/Contents/MacOS/tartube" \
                --replace "@TARTUBE@" "${final.tartube}" \
                --replace "@PATH@" "${final.lib.makeBinPath [ final.yt-dlp final.ffmpeg ]}"

              chmod +x "$app/Contents/MacOS/tartube"
            '';

            meta = {
              description = "Tartube macOS .app bundle (Nix launcher) with icon";
              platforms = [ "x86_64-darwin" "aarch64-darwin" ];
            };
          };
        })
      ];
    };
  in {
    packages.${system} = {
      tartube = pkgs.tartube;

      # Construye el .app con:
      #   nix build .#tartube-app
      tartube-macwrapp = pkgs.tartubeApp;

      # Por defecto, que sea el .app
      default = pkgs.tartubeApp;
    };
  };
}

