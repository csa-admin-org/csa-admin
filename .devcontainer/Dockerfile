# mise.toml pins Ruby 4.0.10. ghcr.io/rails/devcontainer/images/ruby has no
# 4.0.10 tag yet (newest published tag is 4.0.9). mise install below is the
# Ruby the container runs, and the build fails if it is not 4.0.10.
ARG RUBY_VERSION=4.0.9
FROM ghcr.io/rails/devcontainer/images/ruby:$RUBY_VERSION

# Ensure binding is always 0.0.0.0
# Binds the server to all IP addresses of the container, so it can be accessed from outside the container.
ENV BINDING="0.0.0.0"

# Prebake agent tooling and dependencies into the image.
# Each layer is only rebuilt when the files it copies change (mise*.toml, Gemfile*, package.json/aube-lock.yaml).
# The install lands in the image home, not the mounted workspace. postCreateCommand
# still runs mise install and bin/setup there. Debian installs fd as fdfind.
USER root
RUN apt-get update && apt-get install -y --no-install-recommends fish fzf zoxide direnv fd-find openssh-client \
 && rm -rf /var/lib/apt/lists/* \
 && ln -s /usr/bin/fdfind /usr/local/bin/fd

# Litestream for `bin/rails development:restore` (same version as in development).
ARG LITESTREAM_VERSION=0.5.18
ARG TARGETARCH
RUN arch=$([ "$TARGETARCH" = amd64 ] && echo x86_64 || echo "$TARGETARCH") \
 && curl -fsSL "https://github.com/benbjohnson/litestream/releases/download/v${LITESTREAM_VERSION}/litestream-${LITESTREAM_VERSION}-linux-${arch}.tar.gz" \
  | tar -xz -C /usr/local/bin litestream

USER vscode
RUN curl -fsS https://cursor.com/install | bash && mkdir -p ~/.config/cursor ~/.config/gh

WORKDIR /tmp/deps
COPY --chown=vscode:vscode mise*.toml ./
RUN bash -lic 'mise trust && mise install && v=$(ruby -e "print RUBY_VERSION") && test "$v" = 4.0.10 || { echo "expected ruby 4.0.10, got $v"; exit 1; }'

COPY --chown=vscode:vscode Gemfile Gemfile.lock ./
RUN bash -lic 'bundle install --jobs 8'

COPY --chown=vscode:vscode package.json aube-lock.yaml ./
RUN bash -lic 'aube install --frozen-lockfile'

WORKDIR /
