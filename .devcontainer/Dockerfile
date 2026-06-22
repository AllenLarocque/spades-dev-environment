FROM rocker/r-ver:4.5.3

ARG TZ
ENV TZ="$TZ"

ARG CLAUDE_CODE_VERSION=latest

# Install basic development tools and iptables/ipset
RUN apt-get update && apt-get install -y --no-install-recommends \
  less \
  git \
  procps \
  sudo \
  fzf \
  zsh \
  man-db \
  unzip \
  gnupg2 \
  gh \
  iptables \
  ipset \
  iproute2 \
  dnsutils \
  aggregate \
  jq \
  nano \
  vim \
  curl \
  wget \
  ca-certificates \
  && apt-get clean && rm -rf /var/lib/apt/lists/*

# Install Node.js. rocker/r-ver's Ubuntu base doesn't include it -- the
# node:20 image this Dockerfile used to be based on provided Node for free,
# but R itself is the part that needs precise version/library matching, so
# this Dockerfile is now R-first with Node added on top, via NodeSource's
# setup script for the same Node 20.x major version as before.
RUN curl -fsSL https://deb.nodesource.com/setup_20.x | bash - && \
  apt-get install -y --no-install-recommends nodejs && \
  apt-get clean && rm -rf /var/lib/apt/lists/*

# Install the geospatial system libraries needed by terra/sf/GDAL-based
# SpaDES workflows (e.g. LandR Biomass). R itself is already provided by the
# rocker/r-ver base image, built and configured specifically to match the
# Posit Package Manager binary snapshot it also configures as the default
# CRAN mirror -- this is what lets terra/sf/s2 install as prebuilt binaries
# below instead of compiling from source against whatever GDAL/GEOS/PROJ
# happens to be on the system.
RUN apt-get update && apt-get install -y --no-install-recommends \
  libcurl4-openssl-dev \
  libssl-dev \
  libxml2-dev \
  libgdal-dev \
  gdal-bin \
  libgeos-dev \
  libproj-dev \
  libudunits2-dev \
  libsqlite3-dev \
  libfontconfig1-dev \
  libharfbuzz-dev \
  libfribidi-dev \
  libfreetype6-dev \
  libpng-dev \
  libtiff5-dev \
  libjpeg-dev \
  libmagick++-dev \
  libglpk-dev \
  && apt-get clean && rm -rf /var/lib/apt/lists/*

# Install the core SpaDES R package ecosystem (system-wide library, so it's
# available to the node user without a per-project install step).
#
# predictiveecology.r-universe.dev is added because SpaDES.project isn't on
# CRAN at all (GitHub/r-universe only) -- everything else resolves through
# the base image's preconfigured Posit Package Manager repo as prebuilt
# binaries.
#
# install.packages() does not make Rscript exit non-zero when an individual
# package fails to install -- it only warns -- so the explicit check after
# the install call is what actually fails the build on a partial install.
RUN Rscript -e " \
  pkgs <- c('Require', 'reproducible', 'SpaDES.core', 'SpaDES.project', 'terra', 'sf', 'data.table'); \
  options(repos = c(PredictiveEcology = 'https://predictiveecology.r-universe.dev', getOption('repos'))); \
  install.packages(pkgs, Ncpus = parallel::detectCores()); \
  missing <- setdiff(pkgs, rownames(installed.packages())); \
  if (length(missing) > 0) stop('Failed to install: ', paste(missing, collapse = ', ')); \
  "

# Create the non-root "node" user. The node:20 image provided one by
# default; rocker/r-ver's Ubuntu base does not, and deliberately frees up
# uid 1000 for exactly this purpose.
RUN useradd --create-home --shell /bin/bash --uid 1000 node

# Ensure default node user has access to /usr/local/share
RUN mkdir -p /usr/local/share/npm-global && \
  chown -R node:node /usr/local/share

ARG USERNAME=node

# Persist bash history.
RUN SNIPPET="export PROMPT_COMMAND='history -a' && export HISTFILE=/commandhistory/.bash_history" \
  && mkdir /commandhistory \
  && touch /commandhistory/.bash_history \
  && chown -R $USERNAME /commandhistory

# Set `DEVCONTAINER` environment variable to help with orientation
ENV DEVCONTAINER=true

# Create workspace and config directories and set permissions
RUN mkdir -p /workspace /home/node/.claude && \
  chown -R node:node /workspace /home/node/.claude

WORKDIR /workspace

ARG GIT_DELTA_VERSION=0.18.2
RUN ARCH=$(dpkg --print-architecture) && \
  wget "https://github.com/dandavison/delta/releases/download/${GIT_DELTA_VERSION}/git-delta_${GIT_DELTA_VERSION}_${ARCH}.deb" && \
  sudo dpkg -i "git-delta_${GIT_DELTA_VERSION}_${ARCH}.deb" && \
  rm "git-delta_${GIT_DELTA_VERSION}_${ARCH}.deb"

# Set up non-root user
USER node

# Install global packages
ENV NPM_CONFIG_PREFIX=/usr/local/share/npm-global
ENV PATH=$PATH:/usr/local/share/npm-global/bin

# Set the default shell to zsh rather than sh
ENV SHELL=/bin/zsh

# Set the default editor and visual
ENV EDITOR=nano
ENV VISUAL=nano

# Default powerline10k theme
ARG ZSH_IN_DOCKER_VERSION=1.2.0
RUN sh -c "$(wget -O- https://github.com/deluan/zsh-in-docker/releases/download/v${ZSH_IN_DOCKER_VERSION}/zsh-in-docker.sh)" -- \
  -p git \
  -p fzf \
  -a "source /usr/share/doc/fzf/examples/key-bindings.zsh" \
  -a "source /usr/share/doc/fzf/examples/completion.zsh" \
  -a "export PROMPT_COMMAND='history -a' && export HISTFILE=/commandhistory/.bash_history" \
  -x

# Install Claude
RUN npm install -g @anthropic-ai/claude-code@${CLAUDE_CODE_VERSION}

# Pre-install Claude Code plugins so a brand-new named volume (see
# devcontainer.json's mounts: /home/node/.claude) starts out pre-seeded and a
# first-ever container start doesn't need network calls for plugin install.
#
# This alone is NOT sufficient for "rebuild always has the HUD": Docker only
# seeds a named volume from image content the first time that volume is
# created. On a rebuild that reuses an existing claude-code-config-* volume
# (the common case -- rebuilding doesn't delete volumes), whatever's baked
# into the image here is ignored, since the volume already has its own
# content. devcontainer.json's postCreateCommand re-runs these same two
# steps directly against the live mounted ~/.claude on every container
# creation (including rebuilds) to make this idempotent and rebuild-proof --
# that postCreateCommand is the actual source of truth; this RUN step is
# just a warm-start optimization.
#
# The node runtime path is resolved dynamically ($(command -v node)) rather
# than hardcoded, since NodeSource's package installs to /usr/bin/node here,
# not /usr/local/bin/node like the old node:20 base image -- hardcoding it
# would have baked a wrong path into the HUD statusline command.
COPY --chown=node:node bake-plugins.sh configure-claude-settings.js /tmp/
RUN chmod +x /tmp/bake-plugins.sh && \
  /tmp/bake-plugins.sh && \
  node /tmp/configure-claude-settings.js "$(command -v node)" && \
  rm /tmp/bake-plugins.sh /tmp/configure-claude-settings.js


# Copy and set up firewall script
COPY init-firewall.sh /usr/local/bin/
USER root
RUN chmod +x /usr/local/bin/init-firewall.sh && \
  echo "node ALL=(root) NOPASSWD: /usr/local/bin/init-firewall.sh" > /etc/sudoers.d/node-firewall && \
  chmod 0440 /etc/sudoers.d/node-firewall
USER node
