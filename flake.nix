{
  description = "A Rust web server including a NixOS module";

  inputs = {
    # Nixpkgs / NixOS version to use.
    nixpkgs.url = "nixpkgs/nixos-21.05";

    import-cargo.url = github:edolstra/import-cargo;
  };

  outputs = { self, nixpkgs, import-cargo }:
    let
      # Generate a user-friendly version numer.
      version = "${builtins.substring 0 8 self.lastModifiedDate}-${self.shortRev or "dirty"}";

      # System types to support.
      supportedSystems = [ "x86_64-linux" ];

      # Helper function to generate an attrset '{ x86_64-linux = f "x86_64-linux"; ... }'.
      forAllSystems = f: nixpkgs.lib.genAttrs supportedSystems (system: f system);

      # Nixpkgs instantiated for supported system types.
      nixpkgsFor = forAllSystems (system: import nixpkgs { inherit system; overlays = [ self.overlay ]; });

    in {
      # A Nixpkgs overlay.
      overlay = final: prev: {

        lemmy = with final; final.callPackage ({ inShell ? false }: stdenv.mkDerivation rec {
          name = "lemmy-${version}";

          # In 'nix develop', we don't need a copy of the source tree
          # in the Nix store.
          src = if inShell then null else ./.;

          buildInputs =
            [ rustc
              cargo
              pkgconfig
              openssl
              postgresql
              yarn
            ] ++ (if inShell then [
              # In 'nix develop', provide some developer tools.
              rustfmt
              clippy
            ] else [
              (import-cargo.builders.importCargo {
                lockFile = ./Cargo.lock;
                inherit pkgs;
              }).cargoHome
            ]);

          target = "--release";

          buildPhase = "cargo build ${target} --frozen --offline";

          doCheck = true;

          checkPhase = "cargo test ${target} --frozen --offline";

          installPhase =
            ''
              mkdir -p $out
              cargo install --frozen --offline --path . --root $out
              rm $out/.crates.toml
            '';
        }) {};

      };

      # Provide some binary packages for selected system types.
      packages = forAllSystems (system:
        {
          inherit (nixpkgsFor.${system}) lemmy;
        });

      # The default package for 'nix build'. This makes sense if the
      # flake provides only one package or there is a clear "main"
      # package.
      defaultPackage = forAllSystems (system: self.packages.${system}.lemmy);

      # Provide a 'nix develop' environment for interactive hacking.
      devShell = forAllSystems (system: self.packages.${system}.lemmy.override { inShell = true; });

      # A NixOS module.
      nixosModules.lemmy =
        { pkgs, ... }:
        {
          nixpkgs.overlays = [ self.overlay ];

          systemd.services.lemmy = {
            wantedBy = [ "multi-user.target" ];
            serviceConfig.ExecStart = "${pkgs.lemmy}/bin/lemmy_server";
          };
        };

      # Tests run by 'nix flake check' and by Hydra.
      checks = forAllSystems
        (system:
          with nixpkgsFor.${system};

          {
            inherit (self.packages.${system}) lemmy;

            # A VM test of the NixOS module.
            vmTest =
              with import (nixpkgs + "/nixos/lib/testing-python.nix") {
                inherit system;
              };

              makeTest {
                nodes = {
                  client = { ... }: {
                    imports = [ self.nixosModules.lemmy ];
                  };
                };

              testScript =
                ''
                  start_all()
                  client.wait_for_unit("multi-user.target")
                  assert "Hello Nixers" in client.wait_until_succeeds("curl --fail http://localhost:8080/")
                '';
              };
          }
        );
    };
}
