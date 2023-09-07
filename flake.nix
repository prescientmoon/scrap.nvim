{
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
  inputs.flake-utils.url = "github:numtide/flake-utils";

  outputs = inputs@{ nixpkgs, ... }:
    inputs.flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};

        plugins = [
          pkgs.vimPlugins.plenary-nvim

          # We could use a copy of scrap-nvim built using nix, but:
          # - why bother
          # - it would require us to have two separate nvim wrappers
          #   (one for dev and one for testing)
          "./."
        ];

        # Wrap a clean copy of nvim and feeds it a custom runtimepath.
        nvimWrapper = pkgs.symlinkJoin
          {
            name = "nvim-local";
            meta.mainProgram = "nvim-local";

            paths = [ pkgs.neovim ];
            buildInputs = [ pkgs.makeWrapper ];

            postBuild =
              let rtp = pkgs.lib.strings.concatStringsSep "," plugins;
              in
              ''
                wrapProgram $out/bin/nvim \
                  --add-flags "\
                    --clean \
                    --cmd 'lua vim.opt.runtimepath:prepend(\"${rtp}\")' \
                  "
                mv $out/bin/nvim{,-local}
              '';
          };
      in
      {
        devShells.default = pkgs.mkShell {
          packages = [ nvimWrapper ];
        };

        apps.tests = {
          type = "app";
          program = pkgs.lib.getExe (pkgs.writeShellApplication {
            name = "scrap-unit-tests";
            runtimeInputs = [ nvimWrapper ];
            text = ''
              nvim-local \
                --headless \
                -c "PlenaryBustedDirectory ./lua/tests"
            '';
          });
        };
      });
}
