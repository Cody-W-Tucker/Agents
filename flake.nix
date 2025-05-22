{
  description = "A Nix-flake-based Python development environment";

  inputs.nixpkgs.url = "https://flakehub.com/f/NixOS/nixpkgs/0.1.*.tar.gz";

  outputs = { self, nixpkgs }:
    let
      supportedSystems = [ "x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin" ];
      forEachSupportedSystem = f: nixpkgs.lib.genAttrs supportedSystems (system: f {
        pkgs = import nixpkgs { inherit system; };
      });

      /*
       * Change this value ({major}.{min}) to
       * update the Python virtual-environment
       * version. When you do this, make sure
       * to delete the `.venv` directory to
       * have the hook rebuild it for the new
       * version, since it won't overwrite an
       * existing one. After this, reload the
       * development shell to rebuild it.
       * You'll see a warning asking you to
       * do this when version mismatches are
       * present. For safety, removal should
       * be a manual step, even if trivial.
       */
      version = "3.13";
    in
    {
      devShells = forEachSupportedSystem ({ pkgs }:
        let
          concatMajorMinor = v:
            pkgs.lib.pipe v [
              pkgs.lib.versions.splitVersion
              (pkgs.lib.sublist 0 2)
              pkgs.lib.concatStrings
            ];

          python = pkgs."python${concatMajorMinor version}";
        in
        {
          default = pkgs.mkShellNoCC {
            venvDir = ".venv";
            postShellHook = ''
              # Install packages not available in nixpkgs if not already installed
              if ! python -c "import autogen" 2>/dev/null; then
                echo "Installing AutoGen..."
                pip install -U "autogen-agentchat"
                # Install OpenAI extension for model client
                pip install "autogen-ext[openai]"
              fi

              # Install Tavily Python SDK if not already installed
              if ! python -c "import tavily" 2>/dev/null; then
                echo "Installing Tavily Python SDK..."
                pip install tavily-python
              fi

              venvVersionWarn() {
                local venvVersion
              	venvVersion="$("$venvDir/bin/python" -c 'import platform; print(platform.python_version())')"

              	[[ "$venvVersion" == "${python.version}" ]] && return

              	cat <<EOF
              Warning: Python version mismatch: [$venvVersion (venv)] != [${python.version}]
                       Delete '$venvDir' and reload to rebuild for version ${python.version}
              EOF
              }

              venvVersionWarn
            '';

            packages = [
              python.pkgs.venvShellHook
              python.pkgs.pip
              python.pkgs.pydantic
              python.pkgs.notebook
              python.pkgs.jupyter
            ];
          };
        });
    };
}
