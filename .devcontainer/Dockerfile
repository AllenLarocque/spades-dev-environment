FROM node:20

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
  && apt-get clean && rm -rf /var/lib/apt/lists/*

# Add CRAN's apt repository so r-base is a current release. Debian bookworm's
# own r-base is 4.2.2, but current CRAN packages (e.g. SpaDES.core 3.1.2)
# require R >= 4.3 and are reported as "not available for this version of R"
# without this. Key fetched via keyserver per CRAN's documented "Secure apt"
# instructions (https://cloud.r-project.org/bin/linux/debian/) -- the old
# marutter_pubkey.asc URL some guides reference now 404s.
RUN apt-get update && apt-get install -y --no-install-recommends dirmngr \
  && apt-get clean && rm -rf /var/lib/apt/lists/* \
  && gpg --keyserver keyserver.ubuntu.com --recv-key '95C0FAF38DB3CCAD0C080A7BDC78B2DDEABC47B7' \
  && gpg --armor --export '95C0FAF38DB3CCAD0C080A7BDC78B2DDEABC47B7' | tee /etc/apt/trusted.gpg.d/cran_debian_key.asc \
  && echo "deb https://cloud.r-project.org/bin/linux/debian bookworm-cran46/" >> /etc/apt/sources.list

# Install R and the geospatial system libraries needed by terra/sf/GDAL-based
# SpaDES workflows (e.g. LandR Biomass)
RUN apt-get update && apt-get install -y --no-install-recommends \
  r-base \
  r-base-dev \
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
  && apt-get clean && rm -rf /var/lib/apt/lists/*

# Install the core SpaDES R package ecosystem (system-wide library, so it's
# available to the node user without a per-project install step)
RUN Rscript -e "install.packages(c('Require', 'reproducible', 'SpaDES.core', 'SpaDES.project', 'terra', 'sf', 'data.table'), repos = 'https://cloud.r-project.org', Ncpus = parallel::detectCores())"

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

# Pre-install Claude Code plugins so every fresh instance of this template
# has them ready immediately. This relies on Docker seeding a fresh named
# volume from the image's directory contents on first mount: devcontainer.json
# mounts a volume at /home/node/.claude, and whatever exists there in the
# image becomes that volume's initial content on first container start.
COPY --chown=node:node bake-plugins.sh configure-claude-settings.js /tmp/
RUN chmod +x /tmp/bake-plugins.sh && \
  /tmp/bake-plugins.sh && \
  node /tmp/configure-claude-settings.js /usr/local/bin/node && \
  rm /tmp/bake-plugins.sh /tmp/configure-claude-settings.js


# Copy and set up firewall script
COPY init-firewall.sh /usr/local/bin/
USER root
RUN chmod +x /usr/local/bin/init-firewall.sh && \
  echo "node ALL=(root) NOPASSWD: /usr/local/bin/init-firewall.sh" > /etc/sudoers.d/node-firewall && \
  chmod 0440 /etc/sudoers.d/node-firewall
USER node
