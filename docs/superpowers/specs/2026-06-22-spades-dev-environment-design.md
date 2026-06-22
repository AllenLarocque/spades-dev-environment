# spades-dev-environment: design

Date: 2026-06-22
Author: Allen Larocque (design captured by Claude)

## Context

Allen is collaborating on a proposal (`SpaDES as a Modular Statistical Framework for DNA
Barcoding and Community Ecology`) to build a SpaDES-based statistical analysis framework for
DNA barcoding / community ecology, handing off from nf-core/ampliseq-style pipelines into
typed, cached, reusable SpaDES modules.

Before any of that module work starts, the project needs a reproducible, sandboxed development
environment that:
- is safe to run with `claude --dangerously-skip-permissions` (network-sandboxed via firewall,
  non-root user)
- has the system libraries and R/SpaDES package foundation SpaDES workflows need
- is shareable as a starting point for other SpaDES users, not just this one project

The starting point was a clone of `anthropics/claude-code`, whose `.devcontainer/` already
implements the sandboxing pattern (non-root user, iptables/ipset domain allowlist applied via
`postStartCommand`). Allen had been editing that clone's `.devcontainer/Dockerfile` and
`init-firewall.sh` directly to add R/SpaDES support, with project-specific content
(`docs/spades.ai`, `projects/spades_bioinformatics`) dropped in alongside as untracked
directories. None of this belongs in `anthropics/claude-code` — this design moves it into its
own repo.

## Goals

- A standalone, public GitHub template repo that anyone in the SpaDES community can use to spin
  up a sandboxed Claude Code + R/SpaDES dev environment
- Pre-installed: system libs for `terra`/`sf`/GDAL-based SpaDES workflows, core SpaDES R
  packages, and the `superpowers` + `claude-hud` Claude Code plugins — all working immediately
  on first container start, no manual setup
- A network sandbox (firewall allowlist) that covers what SpaDES/R package installation and
  data access actually need: CRAN, Bioconductor, GitHub, Posit Package Manager, r-universe, and
  (for service-account-authenticated downloads) Google Drive
- A `projects/` convention so users can develop their own SpaDES projects inside the same
  workspace, without those projects' code or data living in this template repo

## Non-goals (explicit follow-ups, not part of this design)

- The MTP Microbiome project itself becoming a repo (code-only, `[0] Data/` and `Output/`
  excluded) — separate task, later
- Pre-installing the full bioinformatics R stack (`phyloseq`, `DESeq2`, `vegan`, `iNEXT`,
  `indicspecies`, Quarto, etc.) into the image — these are installed per-project via
  `Require()` at runtime, per the `spades.ai` convention ("never use `library()` or
  `install.packages()`")
- Non-interactive `prepInputs()`-driven Google Drive auth wired into actual SpaDES modules —
  a module-development concern, not a dev-environment concern
- Cleaning up Windows artifacts (`desktop.ini`, `:Zone.Identifier` files) in the existing MTP
  data — only relevant once the MTP repo work starts

## Repo

- Name: `AllenLarocque/spades-dev-environment`
- Visibility: public
- License: GPL-3
- Marked as a GitHub template repository ("Use this template")
- Local working copy: `~/spades-dev-environment` (sibling to the `claude-code` clone, not
  nested inside it)

## Repo structure

```
spades-dev-environment/
├── .devcontainer/
│   ├── Dockerfile
│   ├── devcontainer.json
│   └── init-firewall.sh
├── .github/
│   └── workflows/
│       └── build-devcontainer.yml
├── resources/
│   └── spades.ai/              # git submodule -> AllenLarocque/spades.ai
├── projects/
│   ├── README.md                # convention: clone/init your project repos here
│   └── .gitkeep
├── CLAUDE.md                    # @resources/spades.ai/SPADES-AI.md
├── README.md
├── LICENSE                      # GPL-3
└── .gitignore                   # projects/* (except README/.gitkeep), desktop.ini, *:Zone.Identifier
```

`resources/` is deliberately not named `docs/spades.ai` — it's the general landing spot for
reference material going forward, starting with the `spades.ai` submodule.

Root `CLAUDE.md` imports the submodule's context file (`@resources/spades.ai/SPADES-AI.md`), so
every session in the template automatically gets SpaDES domain knowledge without duplicating
content the `spades.ai` repo owns.

## Devcontainer image (Dockerfile)

Carries over, unchanged in spirit, from the current `claude-code` clone's modified Dockerfile:

- System geospatial libs needed by `terra`/`sf`/GDAL-based SpaDES workflows (e.g. LandR
  Biomass): `libgdal-dev`, `gdal-bin`, `libgeos-dev`, `libproj-dev`, `libudunits2-dev`, etc.
- Core R/SpaDES packages, installed system-wide: `Require`, `reproducible`, `SpaDES.core`,
  `SpaDES.project`, `terra`, `sf`, `data.table`
- No Bioconductor/vegan/phyloseq/etc. baked in (see Non-goals)

New: plugin pre-bake, near the end of the build, as the `node` user:

```dockerfile
RUN claude plugin marketplace add obra/superpowers-marketplace && \
    claude plugin marketplace add jarrodwatts/claude-hud && \
    claude plugin install superpowers@superpowers-marketplace && \
    claude plugin install claude-hud@claude-hud
```

followed by a step that writes the `claude-hud` statusline command into
`/home/node/.claude/settings.json` (same logic as the `/claude-hud:setup` skill, using the
build-time-known `node` binary path from the `node:20` base image), and sets
`skipDangerousModePermissionPrompt: true`.

This works because `/home/node/.claude` is the mount target of a named Docker volume
(`claude-code-config-${devcontainerId}`) in `devcontainer.json`. Docker seeds a fresh named
volume from whatever already exists at that path in the image on first mount — so baking
plugin state into the image at that path means every new instance of the template gets
`superpowers`, `claude-hud`, and a working HUD immediately, with no manual `/plugin install` or
`/claude-hud:setup` step.

**Risk to validate during implementation:** the `claude` CLI's first invocation might expect
interactive onboarding (telemetry/trust prompt) that could hang a `RUN` step with no TTY. The
CI build check is the catch for this; if it happens, the fix is a flag or env var forcing
non-interactive mode for that step.

## Firewall (`init-firewall.sh`)

Carries over the existing script structure (flush rules, restore Docker DNS rules, allow
DNS/SSH/localhost, ipset-based allowlist, default-DROP policy, verification `curl` checks at
the end) unchanged.

Domain allowlist additions, on top of what's already there (GitHub IP ranges via
`api.github.com/meta`, `registry.npmjs.org`, `api.anthropic.com`, `sentry.io`, `statsig.com`,
VS Code marketplace domains, `deb.debian.org`, `cloud.r-project.org`):

- `bioconductor.org` — Bioconductor packages (`phyloseq`, `DESeq2`) installed per-project via
  `Require()`
- `packagemanager.posit.co` — prebuilt Linux binaries for faster installs
- `predictiveecology.r-universe.dev` — PredictiveEcology's r-universe; the script's
  domain-resolution loop only handles exact FQDNs (not wildcards), so additional r-universe
  orgs get added the same way, one FQDN at a time, as they come up
- `raw.githubusercontent.com`, `codeload.github.com`, `objects.githubusercontent.com` — served
  from GitHub's CDN (Fastly), not covered by the existing `api.github.com/meta` IP-range rule,
  but needed for `Require()`/`remotes`-style GitHub package installs (tarball/release downloads)
- `drive.google.com`, `drive.usercontent.google.com` — Google Drive file download endpoints,
  for service-account-authenticated downloads via R's `googledrive` package (which SpaDES
  `prepInputs()` delegates to for Drive URLs)
- `www.googleapis.com` — Drive API v3
- `oauth2.googleapis.com`, `accounts.google.com` — service-account token exchange

This allowlist is explicitly a living list, not a one-time decision — the pattern for adding a
new domain is appending to the `for domain in ...` loop in `init-firewall.sh`.

**Security note on the Google service-account key:** the JSON key itself must never be baked
into the image or committed to the repo. It's supplied at container runtime only, via a
gitignored local file mounted as a volume (see `devcontainer.json` below). This is documented
in the README as opt-in setup, not wired into the template itself.

## `devcontainer.json`

Unchanged from the current clone's version except:

- New optional mount for the Google service-account key, e.g.
  `source=${localEnv:HOME}/.config/spades-dev-environment/gdrive-key.json,target=/home/node/.config/gdrive-key.json,type=bind`
  — only relevant if the file exists on the host; documented as opt-in in the README, not
  required for the base template to work
- `runArgs` (`NET_ADMIN`/`NET_RAW`), `postStartCommand` (`sudo /usr/local/bin/init-firewall.sh`),
  and the `claude-code-config-${devcontainerId}` volume mount stay as-is — that volume mount is
  what makes the plugin pre-bake work

## CI: devcontainer build check

`.github/workflows/build-devcontainer.yml`, runs on every push/PR:

- Builds `.devcontainer/Dockerfile` (e.g. via `devcontainers/ci` or a plain `docker build`) to
  catch a broken Dockerfile/firewall script before merge
- Smoke-checks inside the built image: `R --version`, `Rscript -e 'library(SpaDES.core)'`, and
  `claude plugin list` (to confirm `superpowers` + `claude-hud` actually installed during the
  build — this is also the catch for the "interactive prompt hangs the build" risk noted above)
- Does not attempt to test the firewall script itself (needs `NET_ADMIN`/`NET_RAW` and a real
  container start, awkward on standard GitHub-hosted runners); firewall verification stays
  manual, with the script's own `curl` checks at the end as the safety net at actual container
  start

## README outline

- **What this is** — sandboxed, reproducible devcontainer for SpaDES ecological/bioinformatics
  development, safe to run with `--dangerously-skip-permissions`
- **Quick start** — "Use this template" on GitHub → clone → open in VS Code with Dev Containers
  → Claude Code, `superpowers`, and `claude-hud` ready immediately on first build
- **Adding your project** — the `projects/` convention: clone or `git submodule add` your
  project repo under `projects/`
- **What's pre-installed** — R + core SpaDES packages baked in; everything else via `Require()`
  per-project (link to `resources/spades.ai`)
- **Network sandbox** — what's allowlisted and why; how to add a new domain when a project
  needs one
- **Optional: Google Drive access** — how to supply a service-account key for non-interactive
  `prepInputs()`/`googledrive` downloads; explicitly not committed or baked into the image
- **Contributing** — how to propose Dockerfile/firewall changes, what the CI build check
  verifies
- **License** — GPL-3

## Migration plan (from the `claude-code` clone)

1. `git init` a fresh repo at `~/spades-dev-environment` (done as part of writing this spec)
2. Copy over the current `.devcontainer/Dockerfile` and `init-firewall.sh` from the
   `claude-code` clone (R/SpaDES layer + the CIDR/IP fixes already present there), then layer
   on the plugin pre-bake and extended firewall allowlist described above
3. `git submodule add` for `resources/spades.ai`
4. Discard the `.devcontainer` changes in the `claude-code` clone (`git checkout -- .devcontainer`)
   so it goes back to matching `anthropics/claude-code` upstream — **requires explicit
   confirmation before running**, since it's a destructive `git checkout` on that clone (content
   isn't lost, since it's copied to the new repo first, but it should not be assumed)
5. `gh repo create AllenLarocque/spades-dev-environment --public --license gpl-3.0 --template`
