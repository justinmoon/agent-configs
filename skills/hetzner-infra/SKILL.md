---
name: hetzner-infra
description: NixOS infrastructure on Hetzner. Single host, multiple apps, shared PostgreSQL, Caddy reverse proxy. Use for deployment, NixOS modules, systemd services, and infrastructure philosophy.
---

# Hetzner Infrastructure

Indie SaaS infrastructure on a single Hetzner host running NixOS.

## Philosophy

**Few tools, master them:**
- **PostgreSQL** - One database engine, many databases
- **NixOS** - Declarative, reproducible, rollback-able
- **Caddy** - Auto HTTPS, simple config
- **systemd** - Process supervision, logging

**Avoid:**
- Kubernetes (complexity explosion)
- Multiple database engines
- Vendor lock-in (AWS/GCP managed services)
- Docker in production (NixOS handles it)

**Principles:**
- Single host until you need more
- Shared PostgreSQL (isolation via databases, not instances)
- Everything declarative in nix
- Instant rollback via nix profiles
- Fail loud, no silent degradation

## Architecture

```
┌─────────────────────────────────────────┐
│           Hetzner VPS (NixOS)           │
├─────────────────────────────────────────┤
│  Caddy (443/80)                         │
│    ├─ app1.example.com → :8001          │
│    ├─ app2.example.com → :8002          │
│    └─ app3.example.com → :8003          │
├─────────────────────────────────────────┤
│  PostgreSQL (5432)                      │
│    ├─ app1_db                           │
│    ├─ app2_db                           │
│    └─ app3_db                           │
├─────────────────────────────────────────┤
│  systemd services                       │
│    ├─ app1.service                      │
│    ├─ app2.service                      │
│    └─ app3.service                      │
└─────────────────────────────────────────┘
```

## NixOS Module Pattern

### PostgreSQL Module

```nix
# modules/postgres.nix
{ config, lib, pkgs, ... }:

let cfg = config.services.postgres;
in {
  options.services.postgres = {
    enable = lib.mkEnableOption "PostgreSQL database";
    databases = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = "Databases to create (each gets matching user)";
    };
  };

  config = lib.mkIf cfg.enable {
    services.postgresql = {
      enable = true;
      package = pkgs.postgresql_17;
      settings = {
        listen_addresses = "localhost";
        port = 5432;
      };
      ensureDatabases = cfg.databases;
      ensureUsers = map (db: {
        name = db;
        ensureDBOwnership = true;
      }) cfg.databases;
      authentication = ''
        local   all   all   trust
      '';
    };
  };
}
```

### Caddy Module

```nix
# modules/caddy.nix
{ config, lib, pkgs, ... }:

let cfg = config.services.web;
in {
  options.services.web = {
    enable = lib.mkEnableOption "Caddy reverse proxy";
    acmeEmail = lib.mkOption { type = lib.types.str; };
    sites = lib.mkOption {
      type = lib.types.attrsOf (lib.types.submodule {
        options.port = lib.mkOption { type = lib.types.port; };
        options.extraConfig = lib.mkOption {
          type = lib.types.nullOr lib.types.lines;
          default = null;
        };
      });
      default = {};
    };
  };

  config = lib.mkIf cfg.enable {
    services.caddy = {
      enable = true;
      email = cfg.acmeEmail;
      virtualHosts = lib.mapAttrs (domain: site: {
        extraConfig = ''
          ${lib.optionalString (site.extraConfig != null) site.extraConfig}
          reverse_proxy 127.0.0.1:${toString site.port}
        '';
      }) cfg.sites;
    };
    networking.firewall.allowedTCPPorts = [ 80 443 ];
  };
}
```

### App Service Module

```nix
# modules/myapp.nix
{ config, lib, pkgs, myappPackage, ... }:

let cfg = config.services.myapp;
in {
  options.services.myapp = {
    enable = lib.mkEnableOption "My application";
    package = lib.mkOption {
      type = lib.types.package;
      default = myappPackage;
    };
    port = lib.mkOption {
      type = lib.types.port;
      default = 8000;
    };
    databaseUrl = lib.mkOption {
      type = lib.types.str;
      default = "postgresql:///myapp?host=/run/postgresql";
    };
  };

  config = lib.mkIf cfg.enable {
    # System user
    users.users.myapp = {
      isSystemUser = true;
      group = "myapp";
      home = "/var/lib/myapp";
      createHome = true;
    };
    users.groups.myapp = {};

    # systemd service
    systemd.services.myapp = {
      description = "My Application";
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" "postgresql.service" ];
      requires = [ "postgresql.service" ];

      environment = {
        PORT = toString cfg.port;
        DATABASE_URL = cfg.databaseUrl;
      };

      serviceConfig = {
        Type = "simple";
        User = "myapp";
        Group = "myapp";
        WorkingDirectory = cfg.package;
        EnvironmentFile = "${cfg.package}/.env.prod";
        ExecStartPre = "${pkgs.bun}/bin/bun ${cfg.package}/migrate.ts";
        ExecStart = "${pkgs.bun}/bin/bun ${cfg.package}/server.ts";
        Restart = "always";
        RestartSec = 5;

        # Security hardening
        NoNewPrivileges = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        PrivateTmp = true;
        ReadWritePaths = [ "/run/postgresql" ];
      };
    };
  };
}
```

## Host Configuration

```nix
# hosts/prod.nix
{ config, pkgs, myappPackage, appConfigs, ... }:

{
  imports = [
    ../modules/base.nix
    ../modules/postgres.nix
    ../modules/caddy.nix
    ../modules/myapp.nix
  ];

  networking.hostName = "prod";

  services.postgres = {
    enable = true;
    databases = [ "myapp" "otherapp" ];
  };

  services.myapp = {
    enable = true;
    package = myappPackage;
    port = appConfigs.myapp.port;
  };

  services.web = {
    enable = true;
    acmeEmail = "you@example.com";
    sites = {
      "myapp.example.com" = { port = appConfigs.myapp.port; };
      "otherapp.example.com" = {
        port = appConfigs.otherapp.port;
        extraConfig = ''
          handle /assets/* {
            root * ${otherappPackage}/dist
            file_server
          }
        '';
      };
    };
  };

  system.stateVersion = "25.11";
}
```

## Deployment

### Full System Deploy

```bash
# From repo root
nixos-rebuild switch \
  --flake ".#prod" \
  --target-host root@your-server-ip \
  --build-host root@your-server-ip
```

### Fast App-Only Deploy

```bash
# Build locally
nix build .#myapp

# Copy closure to server
nix copy --to ssh://root@server ./result

# Switch app profile and restart
ssh root@server "
  nix profile install ./result --profile /nix/var/nix/profiles/myapp
  systemctl restart myapp
"
```

### Rollback

```bash
ssh root@server "
  nix profile rollback --profile /nix/var/nix/profiles/myapp
  systemctl restart myapp
"
```

## Database Operations

```bash
# Connect to database
ssh root@server "sudo -u postgres psql myapp"

# Backup
ssh root@server "sudo -u postgres pg_dump myapp" > backup.sql

# Restore
cat backup.sql | ssh root@server "sudo -u postgres psql myapp"
```

## Logs

```bash
# Service logs
ssh root@server "journalctl -u myapp -n 100 --no-pager"

# Follow logs
ssh root@server "journalctl -u myapp -f"

# Caddy logs
ssh root@server "journalctl -u caddy -n 50"

# PostgreSQL logs
ssh root@server "journalctl -u postgresql -n 50"
```

## Debugging on Server

```bash
# Check service status
ssh root@server "systemctl status myapp"

# Check what's listening
ssh root@server "ss -tlnp"

# Check disk space
ssh root@server "df -h"

# Check memory
ssh root@server "free -h"

# Manual service restart
ssh root@server "systemctl restart myapp"
```

## Initial Server Setup

Using disko for declarative disk partitioning:

```nix
disko.devices = {
  disk.main = {
    type = "disk";
    device = "/dev/sda";
    content = {
      type = "gpt";
      partitions = {
        boot = { size = "1M"; type = "EF02"; };
        esp = {
          size = "512M";
          type = "EF00";
          content = {
            type = "filesystem";
            format = "vfat";
            mountpoint = "/boot";
          };
        };
        root = {
          size = "100%";
          content = {
            type = "filesystem";
            format = "ext4";
            mountpoint = "/";
          };
        };
      };
    };
  };
};
```

## Cost

Single Hetzner VPS (~$20-40/month) can run:
- 5+ web apps
- Shared PostgreSQL
- All with HTTPS
- Full NixOS reproducibility
- Instant rollbacks

No need for managed databases, container orchestration, or cloud complexity until you actually need horizontal scaling.
