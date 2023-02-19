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

        pkgs-unstable = import nixpkgs-unstable {
          inherit system;
        };

        lib = pkgs.lib;
        stdenv = pkgs.stdenv;


        fenixChannel = fenix.packages.${system}.stable;
        fenixChannelNightly = fenix.packages.${system}.latest;

        fenixToolchain = (fenixChannel.withComponents [
          "rustc"
          "cargo"
          "clippy"
          "rust-analysis"
          "rust-src"
          "llvm-tools-preview"
        ]);

        fenixToolchainRustfmt = (fenixChannelNightly.withComponents [
          "rustfmt"
        ]);


        craneLib = crane.lib.${system}.overrideToolchain fenixToolchain;


        commonArgs = {
          pname = "fedimint-workspace";
          # src = filterWorkspaceFiles ./.;

          buildInputs = with pkgs; [
            clang
            gcc
            openssl
            pkg-config
            perl
            pkgs.llvmPackages.bintools
            rocksdb
            protobuf
          ] ++ lib.optionals stdenv.isDarwin [
            libiconv
            darwin.apple_sdk.frameworks.Security
            zld
          ] ++ lib.optionals (!(stdenv.isAarch64 || stdenv.isDarwin)) [
            # mold is currently broken on ARM and MacOS
            mold
          ];

          nativeBuildInputs = with pkgs; [
            pkg-config
          ];


          LIBCLANG_PATH = "${pkgs.libclang.lib}/lib/";
          ROCKSDB_LIB_DIR = "${pkgs.rocksdb}/lib/";
          PROTOC = "${pkgs.protobuf}/bin/protoc";
          PROTOC_INCLUDE = "${pkgs.protobuf}/include";
          CI = "true";
          HOME = "/tmp";
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
                fenix.packages.${system}.rust-analyzer
                fenixToolchainRustfmt
                cargo-udeps
                pkgs.parallel
                pkgs.just
                cargo-spellcheck

                (pkgs.writeShellScriptBin "git-recommit" "exec git commit --edit -F <(cat \"$(git rev-parse --git-path COMMIT_EDITMSG)\" | grep -v -E '^#.*') \"$@\"")

                # This is required to prevent a mangled bash shell in nix develop
                # see: https://discourse.nixos.org/t/interactive-bash-with-nix-develop-flake/15486
                (hiPrio pkgs.bashInteractive)
                tmux
                tmuxinator

                # Nix
                pkgs.nixpkgs-fmt
                pkgs.shellcheck
                pkgs.rnix-lsp
                pkgs-unstable.convco
                pkgs.nodePackages.bash-language-server
              ] ++ lib.optionals (!stdenv.isAarch64 || !stdenv.isDarwin) [
                pkgs.semgrep
              ];
              RUST_SRC_PATH = "${fenixChannel.rust-src}/lib/rustlib/src/rust/library";
              LIBCLANG_PATH = "${pkgs.libclang.lib}/lib/";
              ROCKSDB_LIB_DIR = "${pkgs.rocksdb}/lib/";
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

  nixConfig = {
    extra-substituters = [ "https://fedimint.cachix.org" ];
    extra-trusted-public-keys = [ "fedimint.cachix.org-1:FpJJjy1iPVlvyv4OMiN5y9+/arFLPcnZhZVVCHCDYTs=" ];
  };


}
