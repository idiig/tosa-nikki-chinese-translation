{
  description = "Dev environment for Tosa Nikki";

  inputs = {
    nixpkgs.url      = "github:NixOS/nixpkgs/nixos-unstable";
    flake-parts.url  = "github:hercules-ci/flake-parts";
    gloss-tools.url  = "github:idiig/koten-gloss-table-zh";
    # For local development:
    # gloss-tools.url = "path:../koten-gloss-table-zh";
  };

  outputs = inputs@{ self, flake-parts, gloss-tools, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      # Expose outputs for all major platforms
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];

      # Import the provider's flake-parts module (adds apps/packages/devShells)
      imports = [ gloss-tools.flakeModule ];

      perSystem = { pkgs, inputs', lib, system, ... }: {
        # Override the provider's default devShell while reusing it as a base
        devShells.default = lib.mkForce (pkgs.mkShell {
          # Reuse provider devShell contents (jq, make, CLI tools)
          inputsFrom = [ inputs'.gloss-tools.devShells.default ];

          # Add TeX/graphics stack and extra tools
          packages = with pkgs; [
            (texlive.combine {
              inherit (texlive)
                scheme-basic
                xecjk
                latexmk
                fontspec
                graphics
                expex;
            })
            # Fonts
            noto-fonts-cjk-sans
            noto-fonts-cjk-serif
            source-code-pro
            ipafont
            ipaexfont
            # Tools
            inkscape
            ghostscript
            gnumake
          ];
          
          shellHook = ''
            echo "Tosa Nikki dev"
            echo "Usage:"
            echo "  make update              # update the submodule and extract the raw translation"
            echo "  make glossary			       # generate glossary.json"
            echo "  [Note] Manually edit ./build/glossary.json to ./data/glossary.edited.json"
            echo "  make stage			         # stage the edited glossary"
            echo "  make activate			       # activate the edited glossary"
            echo "  make fill			           # fill the glossary abbreviations in the main text"
            echo "  make publish			       # publish the auto-generated results"
            echo "  make publish-edited		   # publish the edited glossary"
          '';
        });

        # Optional: provide local aliases without conflicting with provider names
        apps."gloss-generate" = gloss-tools.apps.${system}.generate-glossary;
        apps."gloss-fill"     = gloss-tools.apps.${system}.fill-glossary;

        # Optional: alias packages for convenience
        packages.zisk = gloss-tools.packages.${system}.zisk-conventions;
        packages.gloss-generate = gloss-tools.packages.${system}.generate-glossary;
        packages.gloss-fill     = gloss-tools.packages.${system}.fill-glossary;
      };
    };
}
