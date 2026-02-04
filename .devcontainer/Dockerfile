FROM elixir:1.19.5-otp-28

RUN apt-get update \
  && apt-get install -y --no-install-recommends \
    build-essential \
    ca-certificates \
    curl \
    git \
    inotify-tools \
  && rm -rf /var/lib/apt/lists/*

ARG USERNAME=vscode
ARG USER_UID=1000
ARG USER_GID=1000

RUN groupadd --gid ${USER_GID} ${USERNAME} \
  && useradd --uid ${USER_UID} --gid ${USER_GID} -m ${USERNAME} \
  && mkdir -p /workspaces \
  && chown -R ${USERNAME}:${USERNAME} /workspaces

# Install Hex and Rebar during image build (has network access)
RUN mix local.hex --force && \
  mix local.rebar --force

# Optional: Pre-install common dependencies
COPY mix.exs mix.lock ./
RUN mix deps.get
RUN mix deps.compile
RUN MIX_ENV=test mix deps.get
RUN MIX_ENV=test mix deps.compile
