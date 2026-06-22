# spades-dev-environment

A sandboxed, reproducible [devcontainer](https://containers.dev/) for developing
[SpaDES](https://spades.predictiveecology.org) ecological and bioinformatics
workflows with [Claude Code](https://claude.com/claude-code) — safe to run with
`--dangerously-skip-permissions` because all outbound network traffic is locked
down to an explicit allowlist.

## Quick start

1. Click **Use this template** on GitHub (or
   `gh repo create my-project --template AllenLarocque/spades-dev-environment --public --clone`).
2. Open the resulting repo in VS Code with the
   [Dev Containers extension](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-containers)
   installed.
3. Run **Dev Containers: Reopen in Container**. First build takes a few minutes.
4. Once it's up, `claude` is ready to go — the `superpowers` and `claude-hud`
   plugins are already installed, and the HUD statusline is already configured.
   No setup commands needed.

## Adding your project

See [`projects/README.md`](projects/README.md). Short version: clone or
`git submodule add` your own SpaDES project repo into `projects/` — it's
gitignored here, so your project's code and data never become part of this
template.

## What's pre-installed

- R 4.5.3, via the [`rocker/r-ver`](https://rocker-project.org) base image
  (Ubuntu noble) rather than a generic Linux image with R bolted on — rocker
  builds R from source with a matched Posit Package Manager binary snapshot
  preconfigured as the default repo, which is what lets `terra`/`sf` install
  as prebuilt binaries instead of compiling from source against whatever
  GDAL/GEOS/PROJ a generic distro image happens to ship. Node.js (for Claude
  Code) is installed on top of this R-first base via NodeSource, not the
  other way around.
- System libraries for `terra`/`sf`/GDAL-based SpaDES workflows (e.g. LandR
  Biomass): GDAL, GEOS, PROJ, udunits2, and friends.
- Core R/SpaDES packages, installed system-wide: `Require`, `reproducible`,
  `SpaDES.core`, `SpaDES.project`, `terra`, `sf`, `data.table`.
- Claude Code plugins `superpowers` and `claude-hud`, pre-installed and
  pre-configured during the image build.

Everything else — `phyloseq`, `DESeq2`, `vegan`, `iNEXT`, `indicspecies`,
Quarto, etc. — is **not** pre-installed. Pull these in per-project with
`Require()` at runtime (never `library()` or `install.packages()` directly —
see [`resources/spades.ai/SPADES-AI.md`](resources/spades.ai/SPADES-AI.md)
for why).

## Network sandbox

`.devcontainer/init-firewall.sh` runs on container start and locks outbound
traffic to an explicit allowlist: GitHub, CRAN (`cloud.r-project.org`),
Bioconductor, Posit Package Manager, r-universe, npm, the Anthropic API, and a
few VS Code/telemetry domains. Everything else is rejected.

If a project needs a new domain (another r-universe org, a data host, etc.),
add it to the `for domain in ...` loop in `init-firewall.sh` — this list is
expected to grow over time, not a one-time decision.

## Optional: Google Drive access

For downloading shared/private datasets via R's `googledrive` package (which
SpaDES `prepInputs()` delegates to for Drive URLs), the firewall allows the
relevant Google domains, but you still need credentials. Use a Google Cloud
**service account** (not interactive browser login — there's no browser in
this container):

1. Create a service account and download its JSON key.
2. Save it on your host machine, *outside* this repo, e.g.
   `~/.config/spades-dev-environment/gdrive-key.json`.
3. Share the relevant Drive files/folders with the service account's email
   address.
4. Add a mount for the key to `.devcontainer/devcontainer.json`'s `mounts`
   array (not included by default, since most users won't need it):
   ```json
   "source=${localEnv:HOME}/.config/spades-dev-environment/gdrive-key.json,target=/home/node/.config/gdrive-key.json,type=bind"
   ```
   Then rebuild the container. The key is never committed or baked into the
   image.

## Contributing

This is a public template meant to be shared and improved by other SpaDES
users. To propose a change to the Dockerfile or firewall script, open a PR —
`.github/workflows/build-devcontainer.yml` builds the image and runs a smoke
check on every PR, so a broken environment gets caught before merge.

## License

GPL-3.0 — see [`LICENSE`](LICENSE).
