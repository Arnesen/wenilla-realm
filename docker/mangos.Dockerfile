# syntax=docker/dockerfile:1.7
# CMaNGOS mangos-classic (GPLv2) + classic-db (GPLv3), built unpatched at the
# commits pinned in upstreams.env. Contains no game data.
ARG MANGOS_CLASSIC_COMMIT
ARG CLASSIC_DB_COMMIT

FROM debian:bookworm AS build
ARG MANGOS_CLASSIC_COMMIT
ARG CLASSIC_DB_COMMIT
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y --no-install-recommends \
      build-essential cmake git ca-certificates \
      libboost-all-dev libmariadb-dev libmariadb-dev-compat libssl-dev zlib1g-dev libbz2-dev \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /opt/src
RUN git clone --recursive https://github.com/cmangos/mangos-classic mangos-classic \
    && git -C mangos-classic checkout --recurse-submodules "${MANGOS_CLASSIC_COMMIT}" \
    && git -C mangos-classic submodule update --init --recursive
RUN git clone https://github.com/cmangos/classic-db classic-db \
    && git -C classic-db checkout "${CLASSIC_DB_COMMIT}" \
    && rm -rf classic-db/.git

# Mirrors the flags proven on the reference install (playerbots + ahbot + extractors).
RUN cmake -S mangos-classic -B /opt/build \
      -DCMAKE_INSTALL_PREFIX=/opt/mangos \
      -DCMAKE_BUILD_TYPE=Release \
      -DBUILD_GAME_SERVER=ON -DBUILD_LOGIN_SERVER=ON \
      -DBUILD_EXTRACTORS=ON -DBUILD_PLAYERBOTS=ON -DBUILD_AHBOT=ON -DPCH=ON \
    && cmake --build /opt/build -j"$(nproc)" \
    && cmake --install /opt/build

# InstallFullDB.sh needs CORE_PATH/sql; keep only that from the core tree.
RUN mkdir -p /opt/core && cp -r mangos-classic/sql /opt/core/sql \
    && mkdir -p /opt/core/contrib && cp -r mangos-classic/contrib/extractor_scripts /opt/core/contrib/extractor_scripts

FROM debian:bookworm-slim
ARG MANGOS_CLASSIC_COMMIT
ARG CLASSIC_DB_COMMIT
LABEL org.opencontainers.image.source="https://github.com/cmangos/mangos-classic" \
      org.opencontainers.image.revision="${MANGOS_CLASSIC_COMMIT}" \
      org.opencontainers.image.licenses="GPL-2.0-only" \
      dev.wenilla.classic-db.source="https://github.com/cmangos/classic-db" \
      dev.wenilla.classic-db.revision="${CLASSIC_DB_COMMIT}"
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y --no-install-recommends \
      bash ca-certificates libmariadb3 libssl3 zlib1g libbz2-1.0 \
      libboost-system1.74.0 libboost-filesystem1.74.0 libboost-program-options1.74.0 \
      libboost-regex1.74.0 libboost-thread1.74.0 \
      mariadb-client gzip \
    && rm -rf /var/lib/apt/lists/* \
    && useradd --system --uid 10001 --create-home --home-dir /home/mangos mangos

COPY --from=build /opt/mangos /opt/mangos
COPY --from=build /opt/src/classic-db /opt/src/classic-db
COPY --from=build /opt/core/sql /opt/src/mangos-classic/sql
COPY --from=build /opt/core/contrib /opt/src/mangos-classic/contrib
COPY docker/db-init.sh docker/conf-defaults.sh docker/extract.sh /opt/realm/
RUN chmod 0755 /opt/realm/*.sh \
    # mangosd resolves anticheat.conf as ../etc/anticheat.conf from its cwd (no CLI flag).
    && ln -sf /config/anticheat.conf /opt/mangos/etc/anticheat.conf \
    && mkdir -p /config /data /logs \
    && chown -R mangos:mangos /opt/mangos /opt/src/classic-db /config /data /logs

ENV PATH="/opt/mangos/bin:${PATH}"
WORKDIR /opt/mangos/bin
# Runtime services run as `mangos` (set in compose); db-init runs as root only
# because it needs nothing but network and the config volume.
