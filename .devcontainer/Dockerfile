FROM elixir:1.19.5-otp-28

RUN apt-get update \
  && apt-get install -y --no-install-recommends \
    build-essential \
    ca-certificates \
    curl \
    git \
    inotify-tools \
  && rm -rf /var/lib/apt/lists/*
