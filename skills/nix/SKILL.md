---
name: nix
description: Nix flakes, devShells, NixOS modules, and build patterns. Use when working with flake.nix, NixOS configs, derivations, or debugging nix issues. Covers Crane (Rust), uv2nix (Python), fixed-output derivations (Bun/npm).
---

# Nix

Reproducible builds and environments via Nix flakes.

## Philosophy

- **Nix is source of truth for deps.** All code runs inside Nix environments.
- **Never skip CI.** Environment is precisely defined - no "missing dependency" excuses.
- **Declarative everything.** Servers run NixOS with same deps as dev.

## Flake Structure

```nix
{
  description = "My project";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
    # Add more inputs as needed
  };

  outputs = { self, nixpkgs }:
  let
    systems = [ "x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin" ];
    forAllSystems = f: nixpkgs.lib.genAttrs systems (system:
      f { pkgs = nixpkgs.legacyPackages.${system}; inherit system; }
    );
  in {
    devShells = forAllSystems ({ pkgs, ... }: {
      default = pkgs.mkShell {
        packages = with pkgs; [ /* deps */ ];
        shellHook = ''
          export IN_NIX_SHELL=1
        '';
      };
    });

    packages = forAllSystems ({ pkgs, ... }: {
      default = /* derivation */;
    });
  };
}
```

## devShells

Development environments with all dependencies.

```nix
devShells = forAllSystems ({ pkgs, system, ... }: {
  default = pkgs.mkShell {
    packages = with pkgs; [
      bun
      postgresql_17
      just
    ];

    # Environment variables
    DATABASE_URL = "postgresql://localhost/myapp";

    # Linux-specific library paths
    LD_LIBRARY_PATH = pkgs.lib.makeLibraryPath [ pkgs.stdenv.cc.cc.lib ];

    shellHook = ''
      export IN_NIX_SHELL=1

      # Auto-install deps when lockfile changes
      mkdir -p .direnv
      if [ ! -d node_modules ] || [ bun.lock -nt .direnv/bun.lock.timestamp ]; then
        bun install
        touch .direnv/bun.lock.timestamp
      fi
    '';
  };
});
```

### direnv Integration

```bash
# .envrc
use flake

# Source .env files
source_env_if_exists .env.dev
source_env_if_exists .env.worktree
```

## Building Rust with Crane

```nix
inputs = {
  crane.url = "github:ipetkov/crane";
  rust-overlay.url = "github:oxalica/rust-overlay";
};

outputs = { self, nixpkgs, crane, rust-overlay }:
let
  mkMyApp = { pkgs, system }:
    let
      overlays = [ (import rust-overlay) ];
      pkgsWithRust = import nixpkgs { inherit system overlays; };
      craneLib = crane.mkLib pkgsWithRust;

      # Filter source to only Cargo files + custom paths
      src = pkgsWithRust.lib.cleanSourceWith {
        src = ./.;
        filter = path: type:
          (craneLib.filterCargoSources path type) ||
          (builtins.match ".*templates/.*" path != null);
      };

      commonArgs = {
        inherit src;
        strictDeps = true;
        buildInputs = with pkgsWithRust; [ openssl pkg-config ];
        nativeBuildInputs = with pkgsWithRust; [ pkg-config ];
      };

      # Build deps separately for caching
      cargoArtifacts = craneLib.buildDepsOnly commonArgs;
    in craneLib.buildPackage (commonArgs // {
      inherit cargoArtifacts;

      # Include extra files in output
      postInstall = ''
        mkdir -p $out/lib/myapp
        cp .env.prod $out/lib/myapp/
        cp -r migrations $out/lib/myapp/
      '';
    });
in { /* ... */ };
```

## Building Python with uv2nix

```nix
inputs = {
  pyproject-nix.url = "github:pyproject-nix/pyproject.nix";
  uv2nix.url = "github:pyproject-nix/uv2nix";
  pyproject-build-systems.url = "github:pyproject-nix/build-system-pkgs";
};

outputs = { self, nixpkgs, pyproject-nix, uv2nix, pyproject-build-systems }:
let
  mkMyPythonApp = { pkgs, system }:
    let
      # Load from pyproject.toml
      workspace = uv2nix.lib.workspace.loadWorkspace { workspaceRoot = ./.; };
      overlay = workspace.mkPyprojectOverlay { sourcePreference = "wheel"; };

      python = pkgs.python312;
      pythonSet = (pkgs.callPackage pyproject-nix.build.packages { inherit python; })
        .overrideScope (nixpkgs.lib.composeManyExtensions [
          pyproject-build-systems.overlays.default
          overlay
        ]);

      venv = pythonSet.mkVirtualEnv "myapp-env" workspace.deps.default;
    in pkgs.runCommand "myapp-prod" {} ''
      mkdir -p $out/bin $out/lib/myapp
      for bin in ${venv}/bin/*; do
        ln -s "$bin" $out/bin/
      done
      cp .env.prod $out/lib/myapp/
    '';
in { /* ... */ };
```

## Building Bun/npm with Fixed-Output Derivations

Platform-specific node_modules require fixed-output derivations:

```nix
# node-modules-hashes.nix
{
  "x86_64-linux" = "sha256-AAAA...";
  "aarch64-linux" = "sha256-BBBB...";
  "x86_64-darwin" = "sha256-CCCC...";
  "aarch64-darwin" = "sha256-DDDD...";
}
```

```nix
nodeModulesHashes = import ./node-modules-hashes.nix;

mkNodeModules = { pkgs, system }: pkgs.stdenv.mkDerivation {
  pname = "myapp-node-modules";
  version = "0.1.0";

  src = nixpkgs.lib.fileset.toSource {
    root = ./.;
    fileset = nixpkgs.lib.fileset.unions [
      ./package.json
      ./bun.lock
    ];
  };

  nativeBuildInputs = with pkgs; [ bun cacert ];

  # Fixed-output: network allowed, cached by hash
  outputHashMode = "recursive";
  outputHashAlgo = "sha256";
  outputHash = nodeModulesHashes.${system};

  buildPhase = ''
    export HOME=$TMPDIR/home
    mkdir -p $HOME
    bun install --frozen-lockfile --no-progress
  '';

  installPhase = ''
    mv node_modules $out
  '';

  dontFixup = true;
};

mkMyApp = { pkgs, system }:
  let nodeModules = mkNodeModules { inherit pkgs system; };
  in pkgs.stdenv.mkDerivation {
    pname = "myapp";
    version = "0.1.0";
    src = ./.;

    nativeBuildInputs = with pkgs; [ bun ];

    buildPhase = ''
      cp -r ${nodeModules} node_modules
      chmod -R u+w node_modules
      export HOME=$TMPDIR/home && mkdir -p $HOME
      bun run build
    '';

    installPhase = ''
      mkdir -p $out
      cp -r dist node_modules src package.json .env.prod $out/
    '';

    dontFixup = true;
  };
```

**Updating hashes:** Run `nix build .#nodeModules` - nix errors with correct hash.

## NixOS Modules

See [hetzner-infra skill](../hetzner-infra/SKILL.md) for NixOS patterns.

## CI Apps

Define runnable apps for CI:

```nix
apps = forAllSystems ({ pkgs, system, ... }: {
  pre-merge = {
    type = "app";
    program = (pkgs.writeShellApplication {
      name = "pre-merge";
      runtimeInputs = with pkgs; [ bun postgresql_17 ];
      text = ''
        export CI=true
        exec "$PWD/scripts/pre-merge.sh"
      '';
    }).outPath + "/bin/pre-merge";
  };
});
```

Run with: `nix run .#pre-merge`

## Common Patterns

### Allow Unfree Packages

```nix
pkgs = import nixpkgs {
  inherit system;
  config.allowUnfreePredicate = pkg:
    builtins.elem (nixpkgs.lib.getName pkg) [ "terraform" ];
};
```

### Library Paths for Native Bindings

```nix
libPath = pkgs.lib.makeLibraryPath [ pkgs.stdenv.cc.cc.lib ];

# In shell or derivation:
LD_LIBRARY_PATH = libPath;  # Linux
DYLD_LIBRARY_PATH = libPath;  # macOS
```

### Playwright Browsers

```nix
inputs.playwright.url = "github:anthropics/playwright-web-flake";

# In shell:
shellHook = ''
  export PLAYWRIGHT_BROWSERS_PATH=${playwright.packages.${system}.playwright-driver.browsers}
  export PLAYWRIGHT_SKIP_VALIDATE_HOST_REQUIREMENTS=true
'';
```

## Debugging

```bash
# Enter shell manually
nix develop

# Build with verbose output
nix build -L

# Show derivation
nix show-derivation .#default

# Repl for exploration
nix repl
:lf .
packages.x86_64-linux.default
```

## Common Errors

| Error | Fix |
|-------|-----|
| `hash mismatch` | Update hash in `node-modules-hashes.nix` |
| `attribute not found` | Check `system` matches your platform |
| `IFD disabled` | Use fixed-output derivation instead |
| `file not found in store` | Add to `src` filter or `postInstall` |
