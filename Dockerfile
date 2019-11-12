FROM node:10.16.0
ARG codeServerVersion=docker
ARG vscodeVersion
ARG githubToken

# Install VS Code's deps. These are the only two it seems we need.
RUN apt-get update && apt-get install -y -qq \
    libxkbfile-dev \
    libsecret-1-dev \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /src
COPY . .

RUN yarn \
	&& MINIFY=true GITHUB_TOKEN="${githubToken}" yarn build "${vscodeVersion}" "${codeServerVersion}" \
	&& yarn binary "${vscodeVersion}" "${codeServerVersion}" \
	&& mv "/src/binaries/code-server${codeServerVersion}-vsc${vscodeVersion}-linux-x86_64" /src/binaries/code-server \
	&& rm -r /src/build \
	&& rm -r /src/source


FROM ubuntu:rolling

RUN locale-gen en_US.UTF-8
# We cannot use update-locale because docker will not use the env variables
# configured in /etc/default/locale so we need to set it manually.
ENV LC_ALL=en_US.UTF-8 \
	SHELL=/bin/bash

RUN apt-get update && apt-get install -y -qq \
    git \
    sudo \
    curl \
    wget \
    nano \
    screen \
    locales \
    openssl \
    net-tools \
    pastebinit \
    inetutils-tools \
    dumb-init \
    && rm -rf /var/lib/apt/lists/*

RUN echo "LC_ALL=en_US.UTF-8" >> /etc/environment \
    && echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen \
    && echo "LANG=en_US.UTF-8" > /etc/locale.conf \
    && locale-gen en_US.UTF-8 \
    \
    && addgroup --gid 1001 coder \
    && adduser --gecos '' --disabled-password --uid 1001 --gid 1001 coder \
	&& echo "coder ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers.d/nopasswd

USER coder
# We create first instead of just using WORKDIR as when WORKDIR creates, the
# user is root.
RUN mkdir -p /home/coder/project \
    && mkdir -p /home/coder/.local/share/code-server \
    && echo "PS1='🐳  \[\033[1;36m\]\u@\h\[\033[0m\] \[\033[1;34m\][\w]\[\033[00m\]\$ '" >> /home/coder/.bashrc

WORKDIR /home/coder/project

# This ensures we have a volume mounted even if the user forgot to do bind
# mount. So that they do not lose their data if they delete the container.
VOLUME [ "/home/coder/project" ]

COPY --from=0 /src/binaries/code-server /usr/local/bin/code-server
EXPOSE 8080

ENTRYPOINT ["dumb-init", "code-server", "--host", "0.0.0.0", "--disable-telemetry"]

ARG VCS_REF
ARG BUILD_DATE
LABEL \
    org.label-schema.vcs-ref=$VCS_REF \
    org.label-schema.build-date=$BUILD_DATE
