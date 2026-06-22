# projects/

This is where your own SpaDES project repos live. This directory is gitignored
(except this file) — nothing you put here becomes part of the
`spades-dev-environment` template.

## Adding a project

Clone your project repo directly into this folder:

```bash
cd projects
git clone https://github.com/<you>/<your-project>.git
```

Or, if you want this template repo to track which version of your project
you're using, add it as a git submodule instead:

```bash
cd projects
git submodule add https://github.com/<you>/<your-project>.git
```

Once it's there, open it in the same VS Code window as this devcontainer —
your project gets the R/SpaDES environment, the network sandbox, and the
`superpowers`/`claude-hud` Claude Code plugins for free, with no per-project
setup.
