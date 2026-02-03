FROM hexpm/elixir:1.19.5-erlang-28.3.1-ubuntu-24.04

RUN apt-get update \
  && apt-get install -y --no-install-recommends \
    build-essential \
    ca-certificates \
    curl \
    git \
    inotify-tools \
  && rm -rf /var/lib/apt/lists/*
