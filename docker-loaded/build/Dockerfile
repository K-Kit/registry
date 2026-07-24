ARG BASE_IMAGE=codercom/enterprise-base:ubuntu
FROM ${BASE_IMAGE}

USER root

RUN apt-get update \
 && apt-get install -y --no-install-recommends \
  build-essential \
  ca-certificates \
  curl \
  git \
  procps \
  python3 \
  sudo \
  tar \
  unzip \
  zsh \
 && rm -rf /var/lib/apt/lists/*

RUN curl -LsSf https://astral.sh/uv/install.sh | env UV_INSTALL_DIR=/usr/local/bin sh

RUN if ! id -u coder >/dev/null 2>&1; then \
      useradd --create-home --shell /bin/bash coder; \
    fi \
  && printf 'coder ALL=(ALL) NOPASSWD:ALL\n' >/etc/sudoers.d/coder \
  && chmod 0440 /etc/sudoers.d/coder

USER coder
WORKDIR /home/coder
