# Keep RUBY_VERSION in sync with the Ruby version in mise.toml
ARG RUBY_VERSION=4.0.10
FROM docker.io/library/ruby:${RUBY_VERSION}-slim

RUN apt-get update && \
    apt-get upgrade -y --no-install-recommends && \
    apt-get install -y --no-install-recommends libvips42t64 && \
    rm -rf /var/lib/apt/lists/*

RUN groupadd --gid 10001 hotcell && \
    useradd --uid 10001 --gid 10001 --no-create-home --shell /usr/sbin/nologin hotcell

# Pre-create the socket mount point owned by hotcell so a fresh Docker volume inherits 10001:10001.
RUN mkdir -p /run/hotcell/cell /hotcell/operations && chown -R hotcell:hotcell /run/hotcell /hotcell

# Match OMP_NUM_THREADS to the active_storage accessory cpus quota in config/deploy.yml.
ENV HOME=/tmp \
    BUNDLE_PATH=/hotcell/bundle \
    BUNDLE_WITHOUT=development \
    BUNDLE_FROZEN=true \
    OMP_NUM_THREADS=2 \
    OMP_THREAD_LIMIT=8 \
    HOTCELL_OPERATIONS=/hotcell/operations \
    HOTCELL_DIR=/run/hotcell/cell

WORKDIR /hotcell

COPY --chown=hotcell:hotcell Gemfile* ./
USER hotcell
RUN bundle install

COPY config.rb /hotcell/config.rb
COPY operations/ /hotcell/operations/

# Hand /hotcell back to root (read-only for workers) and strip setuid/setgid bits across the image.
USER root
RUN chown -R root:root /hotcell && chmod -R go-w /hotcell && \
    find / -xdev -type f -perm /06000 -exec chmod a-s {} +
USER hotcell

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD ["bundle", "exec", "hotcell-health"]

CMD ["bundle", "exec", "hotcell"]
