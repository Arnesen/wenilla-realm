# syntax=docker/dockerfile:1.7
# wenilla (MIT OR Apache-2.0): the browser client compiled to wasm, plus the
# wenilla-realm admin/relay service. Built by CI (~30 min, ~10 GB target/);
# do not build this on the game VM. Contains no game data.
ARG WENILLA_REPO=https://github.com/Arnesen/wenilla
ARG WENILLA_COMMIT=main

FROM rust:1-bookworm AS build
ARG WENILLA_REPO
ARG WENILLA_COMMIT
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y --no-install-recommends \
      clang lld cmake pkg-config brotli curl git ca-certificates \
      libssl-dev libasound2-dev libudev-dev \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /src
RUN git clone "${WENILLA_REPO}" . && git checkout "${WENILLA_COMMIT}"

# web-setup.sh: rustup target wasm32-unknown-unknown, wasm-bindgen-cli at
# EXACTLY the Cargo.lock version, wasi-sdk + binaryen into tools/ (no sudo).
RUN --mount=type=cache,target=/usr/local/cargo/registry \
    --mount=type=cache,target=/usr/local/cargo/git \
    bash scripts/web-setup.sh

# wasm client → web/dist (wenilla.js, wenilla_bg.wasm + .br/.gz, wasi_stubs.js).
RUN --mount=type=cache,target=/usr/local/cargo/registry \
    --mount=type=cache,target=/usr/local/cargo/git \
    --mount=type=cache,target=/src/target \
    WEB_GPU=1 bash scripts/web-build.sh && cp -r web/dist /opt/www

# admin/relay service
RUN --mount=type=cache,target=/usr/local/cargo/registry \
    --mount=type=cache,target=/usr/local/cargo/git \
    --mount=type=cache,target=/src/target \
    cargo build --release -p wenilla-realm && cp target/release/wenilla-realm /opt/wenilla-realm

FROM debian:bookworm-slim
ARG WENILLA_REPO
ARG WENILLA_COMMIT
LABEL org.opencontainers.image.source="${WENILLA_REPO}" \
      org.opencontainers.image.revision="${WENILLA_COMMIT}" \
      org.opencontainers.image.licenses="MIT OR Apache-2.0"
RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates wget \
    && rm -rf /var/lib/apt/lists/* \
    && useradd --system --uid 10002 --create-home realm \
    && mkdir -p /app /state /config && chown realm:realm /state
COPY --from=build /opt/wenilla-realm /app/wenilla-realm
COPY --from=build /opt/www /app/www
# index.html is not served: the service renders its own play page.
RUN rm -f /app/www/index.html
USER realm
ENV REALM_BIND=0.0.0.0:8090 REALM_STATE_DIR=/state REALM_WWW=/app/www RUST_LOG=info
EXPOSE 8090
ENTRYPOINT ["/app/wenilla-realm"]
