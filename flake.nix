{
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
  inputs.flake-utils.url = "github:numtide/flake-utils";

  outputs = inputs@{ nixpkgs, ... }:
    inputs.flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};

        devTools = [ ];

        mkPlugin = name: pkg: pkgs.buildEnv {
          inherit name;
          paths = [ pkg ];
          extraPrefix = "/pack/nix/start/${name}";
        };

        pluginPath = pkgs.symlinkJoin {
          name = "neovim-plugins";
          paths = [
            (mkPlugin "plenary.nvim" pkgs.vimPlugins.plenary-nvim)
          ];
        };

        # Wrap a clean copy of nvim under the name "nvim-local" such that:
        # - plenary.nvim is loaded
        # - the global config is not imported
        # - the current directory is added to the runtimepath
        neovimWrapped = pkgs.symlinkJoin {
          name = "nvim-local";
          paths = [ pkgs.neovim ];
          buildInputs = [ pkgs.makeWrapper ];
          postBuild = ''
            wrapProgram $out/bin/nvim \
              --add-flags "\
                --clean \
                --cmd 'lua vim.opt.packpath = \"${pluginPath}\"' \
                --cmd 'lua vim.opt.runtimepath:prepend(\".\")' \
              "
            mv $out/bin/nvim{,-local}
          '';
        };

        scrap-tests = pkgs.writeShellApplication {
          name = "run-tests";
          runtimeInputs = [ neovimWrapped ];
          text = ''
            nvim-local --headless -c "PlenaryBustedDirectory ./lua/tests"
          '';
        };

      in
      {
        devShells.default = pkgs.mkShell {
          packages = devTools ++ [ neovimWrapped ];
        };

        pkgs = {
          inherit scrap-tests;
        };

        apps = {
          run-tests = {
            type = "app";
            program = pkgs.lib.getExe scrap-tests;
          };
        };
      });
}
