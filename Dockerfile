# syntax=docker/dockerfile:1

ARG BASE_IMAGE=alpine:3.24@sha256:294b683cb724975bec92580e1e685676bd4b50bda910ddb8c51d4cabeaec77e6

###################
# build
###################

FROM ${BASE_IMAGE} AS build

ARG NPROC
ENV NPROC=${NPROC}
ENV CCACHE_DIR=/ccache
ENV CCACHE_MAXSIZE=1G
ENV CCACHE_COMPRESS=1

RUN apk add --no-cache bash git
RUN git config --global --add safe.directory '*'

COPY bin/install_dependencies.sh /usr/local/bin/install_dependencies.sh
RUN install_dependencies.sh

# The git metadata of the submodule changes with every checkout and would
# invalidate the cache of the build stages, so only the version tag is read from it.
FROM build AS version

RUN --mount=type=bind,source=.git/modules/external/monero-project,target=/git \
    git="git --git-dir=/git --work-tree=/tmp" && \
    tag=$($git rev-parse --short=9 HEAD) && \
    if [ -n "$($git tag -l --points-at HEAD)" ]; then tag=release; fi && \
    echo "$tag" > /version

# The sources are bind mounted instead of copied to keep the layers small, and
# only the paths the build needs. VARIANT names a patch in patches/ to apply.
FROM build AS build-monero-daemon-rpc

COPY --from=version /version /version

ARG VARIANT=default
RUN --mount=type=bind,source=bin/build_monero_rpc.sh,target=/src/bin/build_monero_rpc.sh \
    --mount=type=bind,source=bin/build_in_docker.sh,target=/src/bin/build_in_docker.sh \
    --mount=type=bind,source=patches,target=/src/patches \
    --mount=type=bind,source=external/monero-project,target=/src/external/monero-project,rw \
    --mount=type=cache,target=/ccache \
    /src/bin/build_in_docker.sh daemon /out

FROM build AS build-monero-wallet-rpc

COPY --from=version /version /version

ARG VARIANT=default
RUN --mount=type=bind,source=bin/build_monero_rpc.sh,target=/src/bin/build_monero_rpc.sh \
    --mount=type=bind,source=bin/build_in_docker.sh,target=/src/bin/build_in_docker.sh \
    --mount=type=bind,source=patches,target=/src/patches \
    --mount=type=bind,source=external/monero-project,target=/src/external/monero-project,rw \
    --mount=type=cache,target=/ccache \
    /src/bin/build_in_docker.sh wallet_rpc_server /out

# monero-lws is built on the same monero-project, with its patch
FROM build AS build-monero-wallet-light

COPY --from=version /version /version

ARG VARIANT=default
RUN --mount=type=bind,source=bin/build_monero_lws.sh,target=/src/bin/build_monero_lws.sh \
    --mount=type=bind,source=bin/build_in_docker.sh,target=/src/bin/build_in_docker.sh \
    --mount=type=bind,source=patches,target=/src/patches \
    --mount=type=bind,source=external/monero-project,target=/src/external/monero-project,rw \
    --mount=type=bind,source=external/monero-lws,target=/src/external/monero-lws,rw \
    --mount=type=cache,target=/ccache \
    /src/bin/build_in_docker.sh lws /out

###################
# runtime
###################

FROM ${BASE_IMAGE} AS runtime

RUN apk upgrade --no-cache && \
    apk add --no-cache ca-certificates curl && \
    adduser -D -u 1000 monero

ENV HOME=/home/monero

ARG VARIANT=default
LABEL org.opencontainers.image.source="https://github.com/libmonero/docker-monero-rpc" \
      org.opencontainers.image.licenses="MIT AND BSD-3-Clause" \
      io.libmonero.variant="${VARIANT}"

COPY --chmod=0644 docker/healthcheck-common.sh /usr/local/lib/healthcheck-common.sh
COPY external/monero-project/LICENSE /usr/share/licenses/monero-project/LICENSE
COPY LICENSE /usr/share/licenses/docker-monero-rpc/LICENSE
COPY NOTICE /usr/share/licenses/docker-monero-rpc/NOTICE

WORKDIR /home/monero

###################
# monero-daemon-rpc
###################

FROM runtime AS monero-daemon-rpc

COPY --from=build-monero-daemon-rpc /out/monerod /usr/local/bin/monerod
COPY --chmod=0755 docker/healthcheck-monerod.sh /usr/local/bin/healthcheck.sh

LABEL org.opencontainers.image.title="monero-daemon-rpc" \
      org.opencontainers.image.description="monerod built from woodser/monero"

RUN install -d -o monero -g monero /home/monero/.bitmonero
USER 1000:1000

VOLUME /home/monero/.bitmonero

# p2p and rpc
EXPOSE 18080 18081

HEALTHCHECK --interval=30s --timeout=10s --start-period=60s CMD healthcheck.sh

# everything else is up to the user, as arguments or in a config file
ENTRYPOINT ["monerod", "--non-interactive"]

###################
# monero-wallet-rpc
###################

FROM runtime AS monero-wallet-rpc

COPY --from=build-monero-wallet-rpc /out/monero-wallet-rpc /usr/local/bin/monero-wallet-rpc
COPY --chmod=0755 docker/healthcheck-monero-wallet-rpc.sh /usr/local/bin/healthcheck.sh

LABEL org.opencontainers.image.title="monero-wallet-rpc" \
      org.opencontainers.image.description="monero-wallet-rpc built from woodser/monero"

RUN install -d -o monero -g monero /home/monero/wallets
USER 1000:1000

VOLUME /home/monero/wallets

# rpc, monero-wallet-rpc has no default bind port
EXPOSE 18083

HEALTHCHECK --interval=30s --timeout=10s --start-period=30s CMD healthcheck.sh

# everything else is up to the user, as arguments or in a config file
ENTRYPOINT ["monero-wallet-rpc"]

###################
# monero-wallet-light
###################

FROM runtime AS monero-wallet-light

COPY --from=build-monero-wallet-light /out/monero-lws-daemon /out/monero-lws-admin /usr/local/bin/
COPY --chmod=0755 docker/healthcheck-monero-wallet-light.sh /usr/local/bin/healthcheck.sh

LABEL org.opencontainers.image.title="monero-wallet-light" \
      org.opencontainers.image.description="monero-lws light wallet server built against woodser/monero"

# the database is in .bitmonero/light_wallet_server
RUN install -d -o monero -g monero /home/monero/.bitmonero
USER 1000:1000

VOLUME /home/monero/.bitmonero

# rest, the admin rest server has no default bind port
EXPOSE 8443

HEALTHCHECK --interval=30s --timeout=10s --start-period=30s CMD healthcheck.sh

# everything else is up to the user, as arguments or in a config file
ENTRYPOINT ["monero-lws-daemon"]
