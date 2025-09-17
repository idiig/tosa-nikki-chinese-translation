{
  description = "Dev environment for Tosa Nikki";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs =
    { self, nixpkgs }:
    let
      allSystems = [
        "x86_64-linux"
        "aarch64-linux" 
        "x86_64-darwin"
        "aarch64-darwin"
      ];

      forAllSystems =
        f:
        nixpkgs.lib.genAttrs allSystems (
          system:
          f {
            pkgs = import nixpkgs { inherit system; };
          }
        );
    in
    {
      devShells = forAllSystems (
        { pkgs }:
        {
          default = pkgs.mkShell {
            packages = with pkgs; [
              jq

              # LaTeX 发行版
              (texlive.combine {
                inherit (texlive) 
                  scheme-basic
                  xecjk
                  latexmk
                  fontspec
                  
                  # 图形和绘图
                  graphics
                                    
                  # 语言学包
                  expex;
              })
              
              # 字体
              noto-fonts-cjk-sans
              noto-fonts-cjk-serif
              source-code-pro
              ipafont
              ipaexfont
              
              # 工具
              inkscape
              ghostscript      # PDF 处理工具
            ];
            
            shellHook = ''
              echo "Tosa Nikki dev"
              echo ""
              echo "Usage:"
              echo "  latexmk document.tex    # 自动编译"
              echo "  xelatex -shell-escape document.tex  # 手动编译"
              echo ""
              
              fc-cache -f 2>/dev/null || true
              
              echo "Tools available:"
              echo "  Inkscape: $(inkscape --version 2>/dev/null | head -1 || echo 'Not found')"
              echo "  Shell escape: Enabled in latexmkrc"
            '';
          };
        }
      );
    };
}
