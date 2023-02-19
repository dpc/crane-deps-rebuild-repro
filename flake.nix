{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-22.11";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";
    crane.url = "github:ipetkov/crane?ref=v0.11.2";
    crane.inputs.nixpkgs.follows = "nixpkgs";
    flake-utils.url = "github:numtide/flake-utils";
    fenix = {
      url = "github:nix-community/fenix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    flake-compat = {
      url = "github:edolstra/flake-compat";
      flake = false;
    };
    advisory-db = {
      url = "github:rustsec/advisory-db";
      flake = false;
    };
  };

  outputs = { self, nixpkgs, nixpkgs-unstable, flake-utils, flake-compat, fenix, crane, advisory-db }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system;
        };

        fenixChannel = fenix.packages.${system}.stable;

        fenixToolchain = (fenixChannel.withComponents [
          "rustc"
          "cargo"
          "clippy"
          "rust-analysis"
          "rust-src"
        ]);


        craneLib = crane.lib.${system}.overrideToolchain fenixToolchain;


        commonArgs = {
          pname = "fedimint-workspace";

          buildInputs = [
          ];

          nativeBuildInputs = with pkgs; [
            pkg-config
          ];
        };

        workspaceDeps = craneLib.buildDepsOnly (commonArgs // {
          src = ./.;
        });



        # outputs that do something over the whole workspace
        outputsWorkspace = {
          inherit workspaceDeps
            ;

        };


        packages = outputsWorkspace

        ;
      in
      {
        inherit packages;



        devShells =

          let
            shellCommon = {
              buildInputs = commonArgs.buildInputs;
              nativeBuildInputs = with pkgs; commonArgs.nativeBuildInputs ++ [

                # This is required to prevent a mangled bash shell in nix develop
                # see: https://discourse.nixos.org/t/interactive-bash-with-nix-develop-flake/15486
                (hiPrio pkgs.bashInteractive)
              ];
              RUST_SRC_PATH = "${fenixChannel.rust-src}/lib/rustlib/src/rust/library";
              LIBCLANG_PATH = "${pkgs.libclang.lib}/lib/";
            };

          in
          {
            # The default shell - meant to developers working on the project,
            # so notably not building any project binaries, but including all
            # the settings and tools neccessary to build and work with the codebase.
            default = pkgs.mkShell (shellCommon
              // {
              nativeBuildInputs = shellCommon.nativeBuildInputs ++ [ fenixToolchain ];
            });

          };
      });


}
