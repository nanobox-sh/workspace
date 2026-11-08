# syntax=docker/dockerfile:1

# "Coding Agents": the nanobox workspace image with Claude Code, Codex and Pi.
#
# nanobox starts this image as a long-running container with uid 1000, host
# networking, and /home/dev and /workspace bind-mounted from the box's disk.
# Everything in this image therefore lives under system paths: nothing that
# must be present at runtime may be placed in /home/dev, because the mount
# hides it.

ARG UBUNTU_VERSION=24.04
ARG UV_VERSION=0.13.7

FROM ghcr.io/astral-sh/uv:${UV_VERSION} AS uv

FROM ubuntu:${UBUNTU_VERSION}

ARG TARGETARCH
ARG NODE_VERSION=24.22.2
ARG CLAUDE_CODE_CHANNEL=latest
ARG CODEX_VERSION=latest
ARG PI_VERSION=latest

ENV DEBIAN_FRONTEND=noninteractive \
    LANG=en_US.UTF-8 \
    LC_ALL=en_US.UTF-8 \
    TZ=UTC

RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    apt-get update && apt-get install -y --no-install-recommends \
      bash-completion \
      build-essential \
      ca-certificates \
      curl \
      dnsutils \
      fd-find \
      file \
      fzf \
      git \
      git-lfs \
      gnupg \
      htop \
      iproute2 \
      iputils-ping \
      jq \
      less \
      locales \
      lsb-release \
      make \
      nano \
      openssh-client \
      patch \
      pkg-config \
      procps \
      python3 \
      python3-pip \
      python3-venv \
      ripgrep \
      rsync \
      sqlite3 \
      sudo \
      tmux \
      tree \
      tzdata \
      unzip \
      vim \
      wget \
      xz-utils \
      zip \
      zsh \
    && ln -s /usr/bin/fdfind /usr/local/bin/fd \
    && locale-gen en_US.UTF-8

# Third-party apt repositories: Docker CLI (the box's engine socket is mounted
# into the container), GitHub CLI, and Claude Code. Each key is pinned to the
# repository it signs; Anthropic's is additionally checked against the
# fingerprint they publish, so a swapped key fails the build.
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    set -eux; \
    arch="$(dpkg --print-architecture)"; \
    install -d -m 0755 /etc/apt/keyrings; \
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc; \
    echo "deb [arch=${arch} signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" \
      > /etc/apt/sources.list.d/docker.list; \
    curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg -o /etc/apt/keyrings/githubcli-archive-keyring.gpg; \
    echo "deb [arch=${arch} signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
      > /etc/apt/sources.list.d/github-cli.list; \
    curl -fsSL https://downloads.claude.ai/keys/claude-code.asc -o /etc/apt/keyrings/claude-code.asc; \
    gpg --show-keys --with-colons /etc/apt/keyrings/claude-code.asc \
      | grep -q '^fpr:*31DDDE24DDFAB679F42D7BD2BAA929FF1A7ECACE:'; \
    echo "deb [signed-by=/etc/apt/keyrings/claude-code.asc] https://downloads.claude.ai/claude-code/apt/${CLAUDE_CODE_CHANNEL} ${CLAUDE_CODE_CHANNEL} main" \
      > /etc/apt/sources.list.d/claude-code.list; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
      docker-ce-cli docker-buildx-plugin docker-compose-plugin \
      gh \
      claude-code

RUN set -eux; \
    case "${TARGETARCH}" in \
      amd64) node_arch=x64 ;; \
      arm64) node_arch=arm64 ;; \
      *) echo "unsupported TARGETARCH ${TARGETARCH}" >&2; exit 1 ;; \
    esac; \
    tarball="node-v${NODE_VERSION}-linux-${node_arch}.tar.xz"; \
    cd /tmp; \
    curl -fsSLO "https://nodejs.org/dist/v${NODE_VERSION}/${tarball}"; \
    curl -fsSLO "https://nodejs.org/dist/v${NODE_VERSION}/SHASUMS256.txt"; \
    grep " ${tarball}\$" SHASUMS256.txt | sha256sum -c -; \
    tar -xJf "${tarball}" -C /usr/local --strip-components=1 --no-same-owner \
      --exclude CHANGELOG.md --exclude LICENSE --exclude README.md; \
    rm -f "${tarball}" SHASUMS256.txt; \
    npm install -g --no-fund --no-audit \
      "@openai/codex@${CODEX_VERSION}" \
      "@earendil-works/pi-coding-agent@${PI_VERSION}"; \
    npm cache clean --force

COPY --from=uv /uv /uvx /usr/local/bin/

# The box user. nanobox assumes uid 1000 and writes the login name it was
# asked for into the container's passwd file, so the entry only has to exist
# with that uid; "dev" is the platform default. Ubuntu's image ships its own
# uid 1000 account, which is removed so the name is free.
RUN set -eux; \
    if id ubuntu >/dev/null 2>&1; then userdel -r ubuntu; fi; \
    groupadd --gid 1000 dev; \
    useradd --uid 1000 --gid 1000 --create-home --home-dir /home/dev --shell /bin/bash dev; \
    install -d -m 0755 -o dev -g dev /workspace

COPY rootfs/ /
RUN chmod 0440 /etc/sudoers.d/dev && visudo -cf /etc/sudoers.d/dev \
    && chmod 0755 /usr/local/bin/workspace-versions \
    && workspace-versions > /etc/workspace-versions

# Claude Code cannot update a system-wide install from a session, so it is
# told not to try. These apply to every process in the container, login shell
# or not.
ENV DISABLE_AUTOUPDATER=1 \
    EDITOR=vim

LABEL org.opencontainers.image.title="Coding Agents" \
      org.opencontainers.image.description="nanobox workspace with Claude Code, Codex, Pi, Node.js, Python (uv), Docker CLI and GitHub CLI" \
      org.opencontainers.image.source="https://github.com/nanobox-sh/workspace" \
      org.opencontainers.image.url="https://nanobox.sh" \
      org.opencontainers.image.vendor="nanobox.sh" \
      org.opencontainers.image.licenses="MIT"

USER dev
WORKDIR /home/dev
CMD ["/bin/bash", "-l"]
