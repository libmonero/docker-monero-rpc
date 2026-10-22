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

# The sources are bind mounted instead of copied to keep the layers small, and
# only the paths the build needs, so unrelated changes do not rebuild it. The
# git metadata of the submodule is there for the version monero-project reports.
FROM build AS build-monero-daemon-rpc

RUN --mount=type=bind,source=bin,target=/src/bin \
    --mount=type=bind,source=external,target=/src/external,rw \
    --mount=type=bind,source=.git/modules/external/monero-project,target=/src/.git/modules/external/monero-project,rw \
    --mount=type=cache,target=/ccache \
    cd /src && ./bin/build_monero_rpc.sh daemon && \
    strip --strip-unneeded -o /monerod external/monero-project/build/release/bin/monerod

FROM build AS build-monero-wallet-rpc

RUN --mount=type=bind,source=bin,target=/src/bin \
    --mount=type=bind,source=external,target=/src/external,rw \
    --mount=type=bind,source=.git/modules/external/monero-project,target=/src/.git/modules/external/monero-project,rw \
    --mount=type=cache,target=/ccache \
    cd /src && ./bin/build_monero_rpc.sh wallet_rpc_server && \
    strip --strip-unneeded -o /monero-wallet-rpc external/monero-project/build/release/bin/monero-wallet-rpc

###################
# runtime
###################

FROM ${BASE_IMAGE} AS runtime

RUN apk add --no-cache ca-certificates curl && \
    adduser -D -u 1000 monero

WORKDIR /home/monero

###################
# monero-daemon-rpc
###################

FROM runtime AS monero-daemon-rpc

COPY --from=build-monero-daemon-rpc /monerod /usr/local/bin/monerod
COPY --chmod=0755 docker/healthcheck-monerod.sh /usr/local/bin/healthcheck.sh

RUN install -d -o monero -g monero /home/monero/.bitmonero
USER monero

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

COPY --from=build-monero-wallet-rpc /monero-wallet-rpc /usr/local/bin/monero-wallet-rpc
COPY --chmod=0755 docker/healthcheck-monero-wallet-rpc.sh /usr/local/bin/healthcheck.sh

RUN install -d -o monero -g monero /home/monero/wallets
USER monero

VOLUME /home/monero/wallets

# rpc, monero-wallet-rpc has no default bind port
EXPOSE 18083

HEALTHCHECK --interval=30s --timeout=10s --start-period=30s CMD healthcheck.sh

# everything else is up to the user, as arguments or in a config file
ENTRYPOINT ["monero-wallet-rpc"]
