---
Date: 2026-10-21
Status: Accepted
Triggers:
  - deploy fails or behaves unexpectedly
  - changing the server proxy or port configuration
  - questions about Hatchbox, Caddy, or Kamal on this server
Topics: deployment, infrastructure
---

# ADR 019 -- Kamal Is the Sole Deployment System

## Context

After a server reboot on 2026-10-05, Caddy started before Docker and grabbed
ports 80 and 443. kamal-proxy was already running inside Docker but could not
bind to those ports, so it sat idle. Caddy routed traffic to a Hatchbox-managed
Puma process on port 9000 instead.

This left the server running two parallel deployment systems:

- **Hatchbox** — Caddy frontend, Puma on port 9000, auto-deploys on push to
  main. Was the active system from Oct 5 onwards without anyone noticing.
- **Kamal** — kamal-proxy in Docker, intended to own 80/443, was not serving
  traffic. On top of the port conflict, kamal-proxy's `/etc/resolv.conf` pointed
  to `127.0.0.53` (the host systemd-resolved stub, unreachable from inside
  Docker) rather than Docker's internal resolver `127.0.0.11`, so new container
  names failed to resolve during health checks. The GitHub Actions deploy
  workflow had been failing silently since Oct 5.

The duplicate setup was invisible because both systems tracked the same git
branch and the app stayed available throughout.

## Decision

**Kamal is the sole deployment system. Hatchbox is retired.**

On 2026-10-21 the following changes were made to the production server
(172.105.171.81):

1. **Docker DNS fixed.** `/etc/docker/daemon.json` set to
   `{"dns": ["8.8.8.8", "8.8.4.4"]}` so containers can resolve names
   independently of the host's systemd-resolved stub.

2. **Caddy stopped and disabled.** `systemctl stop caddy && systemctl disable caddy`.
   Caddy will not restart on reboot.

3. **Docker restarted.** `systemctl restart docker` caused kamal-proxy to restart
   with correct DNS and claim ports 80 and 443 now that Caddy was gone.

4. **CI deploy verified.** A version bump (20261021.2) was pushed, the GitHub
   Actions workflow went green (tests + e2e + deploy all passed), and the new
   version was confirmed live on the first poll of `/api/version`.

## Consequences

- The GitHub Actions `deploy.yml` workflow is the only deploy path. Pushing to
  `main` is the only way to ship.
- Hatchbox should no longer be used to manage this app. If the Hatchbox dashboard
  still exists, it can be decommissioned.
- If the server reboots, kamal-proxy will restart via Docker's restart policy and
  reclaim ports 80/443 before Caddy can interfere (Caddy is disabled).
- If a future maintainer sees port 9000 in logs, it is a ghost — Hatchbox Puma
  is not running.
- The local `kamal deploy` command should not be run manually. CI writes a fresh
  `.kamal/secrets` from GitHub Actions secrets at deploy time; the local copy
  in `.kamal/secrets` may be stale.
