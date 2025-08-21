{
  description = "Development environment for codeview.nvim";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let pkgs = nixpkgs.legacyPackages.${system};
      in {
        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            # Core development tools
            neovim
            git
            lua5_1
            luajit

            # Lua development and formatting tools
            stylua
            lua-language-server
          ];

          shellHook = ''
            echo "🚀 codeview.nvim development environment loaded!"
            echo ""
            echo "Available tools:"
            echo "  - neovim: $(nvim --version | head -1)"
            echo "  - git: $(git --version)"
            echo "  - lua: $(lua -v)"
            echo "  - stylua: Lua formatter"
            echo "  - lua-language-server: LSP for Lua"
            echo ""
            echo "Quick commands:"
            echo "  stylua . --check      # Check Lua formatting"
            echo "  stylua .              # Format Lua files"
            echo ""
          '';

          # Set environment variables for Lua development
          LUA_PATH = "./lua/?.lua;./lua/?/init.lua;;";
          LUA_CPATH = ";;";
        };

        # Optional: formatter for the flake itself
        formatter = pkgs.nixpkgs-fmt;
      });
}

