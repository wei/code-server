FROM node:10.15.1

# Install VS Code's deps. These are the only two it seems we need.
RUN apt-get update && apt-get install -y -qq \
	libxkbfile-dev \
    libsecret-1-dev \
    && rm -rf /var/lib/apt/lists/*

# Ensure latest yarn.
RUN npm install -g yarn@1.13

WORKDIR /src
COPY . .

# In the future, we can use https://github.com/yarnpkg/rfcs/pull/53 to make yarn use the node_modules
# directly which should be fast as it is slow because it populates its own cache every time.
RUN yarn && NODE_ENV=production yarn task build:server:binary


FROM ubuntu:rolling

RUN apt-get update && apt-get install -y -qq \
    openssl \
    net-tools \
    inetutils-tools \
    git \
    locales \
    sudo \
    dumb-init \
    curl \
    wget \
    && rm -rf /var/lib/apt/lists/*

RUN echo "LC_ALL=en_US.UTF-8" >> /etc/environment && \
    echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen && \
    echo "LANG=en_US.UTF-8" > /etc/locale.conf && \
    locale-gen en_US.UTF-8 && \
    \
    adduser --gecos '' --disabled-password coder && \
	  echo "coder ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers.d/nopasswd

USER coder
# We create first instead of just using WORKDIR as when WORKDIR creates, the user is root.
RUN mkdir -p /home/coder/project \
    && mkdir -p /home/coder/.local/share/code-server

WORKDIR /home/coder/project

# This assures we have a volume mounted even if the user forgot to do bind mount.
# So that they do not lose their data if they delete the container.
VOLUME [ "/home/coder/project" ]

COPY --from=0 /src/packages/server/cli-linux-x64 /usr/local/bin/code-server
EXPOSE 8443

ENTRYPOINT ["dumb-init", "code-server"]
