---
name: monorepo-patterns
description: Multi-app monorepo conventions. Per-app flakes, standardized justfiles, shared PostgreSQL, worktree isolation, CI patterns. Use when creating new apps, debugging environment issues, or understanding project structure.
---

# Monorepo Patterns

Conventions for multi-app monorepos with Nix + Just.

## Philosophy

- **Nix is source of truth for deps.** No "works on my machine."
- **Just is source of truth for commands.** `just <cmd>` everywhere.
- **Never skip CI.** Environment is defined - no excuses.
- **Fail loud.** Missing config = error, not default.
- **Test coverage enables CD.** Every user action has a test.

## Project Structure

```
monorepo/
├── flake.nix              # Root flake (composes apps, NixOS configs)
├── justfile               # Root commands (pre-merge, deploy)
├── AGENTS.md              # Agent conventions
├── docs/                  # Shared documentation
├── infra/nix/             # NixOS modules and hosts
├── scripts/               # Shared scripts
└── projects/
    ├── app1/
    │   ├── flake.nix      # App-specific devShell + package
    │   ├── justfile       # App commands
    │   ├── CLAUDE.md      # App-specific agent docs
    │   ├── .envrc         # direnv config
    │   ├── .env.dev       # Dev environment
    │   └── .env.prod      # Prod environment (bundled in nix)
    └── app2/
        └── ...
```

## Per-App Flake Pattern

Each app has its own `flake.nix`:

```nix
{
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";

  outputs = { self, nixpkgs }:
  let
    systems = [ "x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin" ];
    forAllSystems = f: nixpkgs.lib.genAttrs systems (system:
      f { pkgs = nixpkgs.legacyPackages.${system}; inherit system; }
    );
  in {
    devShells = forAllSystems ({ pkgs, ... }: {
      default = pkgs.mkShell {
        packages = with pkgs; [ /* app deps */ ];
        shellHook = ''
          export IN_NIX_SHELL=1
        '';
      };
    });

    packages = forAllSystems ({ pkgs, ... }: {
      default = /* production build */;
    });

    apps = forAllSystems ({ pkgs, ... }: {
      pre-merge = { type = "app"; program = /* ... */; };
      post-merge = { type = "app"; program = /* ... */; };
    });
  };
}
```

## Standard Justfile

Every app has these commands:

```just
set shell := ["bash", "-eu", "-o", "pipefail", "-c"]

[private]
nix-check:
    @test -n "${IN_NIX_SHELL:-}" || (echo "Run 'nix develop' first" && exit 1)

default:
    @just --list

# Development
dev: nix-check
    # start dev server

# Checks
check: nix-check
    # type checking

lint: nix-check
    # linting + format check

format: nix-check
    # auto-fix formatting

test: nix-check
    # unit/integration tests

test-e2e *args: nix-check
    # E2E tests (playwright)
    playwright test {{args}}

# CI
pre-merge: check lint test test-e2e
    @echo "All checks passed!"

# Database
pg-start:
    ../../scripts/pg-start.sh
    # Create app-specific database if needed

pg-stop:
    ../../scripts/pg-stop.sh

db-setup: pg-start
    # run migrations

db-reset: pg-start
    # drop + recreate + migrate
```

## Shared PostgreSQL

All apps share one PostgreSQL instance (port 5434 by default):

```bash
# scripts/pg-start.sh
PGPORT="${PGPORT:-5434}"
PGDATA="${PGDATA:-$HOME/.local/share/monorepo-postgres}"

if pg_isready -h localhost -p "$PGPORT" &>/dev/null; then
  exit 0  # Already running
fi

if [ ! -d "$PGDATA" ]; then
  initdb -D "$PGDATA"
  echo "port = $PGPORT" >> "$PGDATA/postgresql.conf"
fi

pg_ctl -D "$PGDATA" -l "$PGDATA/logfile" start
```

Each app creates its own database:

```bash
# In app's justfile pg-start recipe
PGPORT="${PGPORT:-5434}"
if ! psql -h localhost -p "$PGPORT" -lqt | cut -d \| -f 1 | grep -qw myapp; then
  createdb -h localhost -p "$PGPORT" myapp
fi
```

## direnv Integration

```bash
# .envrc
use flake

# Load environment files
source_env_if_exists .env.dev
source_env_if_exists .env.worktree

# Worktree isolation
if [[ "$PWD" == *"/worktrees/"* ]]; then
  source_env "$(git rev-parse --show-toplevel)/scripts/worktree-env"
fi
```

## Git Worktrees for Parallel Work

For concurrent agents/features, use worktrees:

```bash
# Create worktree
git worktree add worktrees/my-feature -b my-feature

# Enter and work
cd worktrees/my-feature/projects/myapp
just dev  # Uses isolated database: myapp__my_feature
```

Auto-generated `.env.worktree`:
```bash
# Isolated database names
DB_NAME=myapp__my_feature

# Isolated ports (hash-based)
PORT=3847
```

## Environment Variables

```bash
# .env.dev (local development)
DATABASE_URL=postgresql://localhost:5434/myapp
PORT=3000
DEBUG=true

# .env.prod (bundled in nix package)
DATABASE_URL=postgresql:///myapp?host=/run/postgresql
PORT=8000

# .env.worktree (auto-generated, gitignored)
DB_NAME=myapp__feature_branch
PORT=3847
```

**Rule:** No defaults for required config. Missing = error.

## CI Patterns

### Local Pre-Merge

```bash
# Run all checks
just pre-merge

# Or via nix app
nix run .#pre-merge
```

### Root Orchestration

```bash
# Root justfile
pre-merge:
    cd projects/app1 && nix develop -c just pre-merge
    cd projects/app2 && nix develop -c just pre-merge

post-merge:
    ./scripts/post-merge.sh
```

### Remote Debugging

```bash
# Sync to build server and run command
just hetzner-exec "cd projects/myapp && nix develop -c just test-e2e"
```

## Creating a New App

1. **Create directory structure:**
```bash
mkdir -p projects/newapp
cd projects/newapp
```

2. **Create flake.nix** (see pattern above)

3. **Create justfile** (see pattern above)

4. **Create .envrc:**
```bash
use flake
source_env_if_exists .env.dev
source_env_if_exists .env.worktree
```

5. **Create .env.dev:**
```bash
DATABASE_URL=postgresql://localhost:5434/newapp
PORT=3000
```

6. **Create CLAUDE.md** with app-specific docs

7. **Wire into root flake** (if deploying via NixOS)

8. **Add to root pre-merge:**
```bash
# In root scripts/pre-merge.sh
cd projects/newapp && nix develop -c just pre-merge
```

## App Configuration Map

Define app configs in root flake for consistency:

```nix
appConfigs = {
  app1 = { port = 8001; domain = "app1.example.com"; };
  app2 = { port = 8002; domain = "app2.example.com"; };
};
```

Used by:
- NixOS modules (port assignment)
- Caddy config (domain routing)
- Local dev (port defaults)

## Testing Conventions

- **Unit tests:** `just test`
- **E2E tests:** `just test-e2e`
- **Single test:** `just test-e2e tests/e2e/auth.spec.ts`
- **All CI:** `just pre-merge`

E2E tests run against real PostgreSQL. No mocking the database.

## Common Commands

```bash
# Enter app shell
cd projects/myapp
# (direnv activates automatically)

# Or manually
nix develop

# Run dev server
just dev

# Run all checks
just pre-merge

# Format code
just format

# Run specific test
just test-e2e tests/e2e/login.spec.ts

# Database operations
just pg-start
just db-setup
just db-reset
```
