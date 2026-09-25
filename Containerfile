# mcl-bookclub-gleam: the Bookclub-on-Mesh in Gleam -- the drop-in twin of
# mcl-bookclub and mcl-bookclub-phoenix: a THIRD club on the mesh, same org,
# same topics, same procedure names, a different node identity.
#
# PINNED BY DIGEST, and the SAME images CI uses, so what ships is what was
# tested. The builder is ghcr.io/macula-io/macula-ci-gleam (Gleam 1.18.1 on
# OTP 28.4.3, rebar3 and Rust pinned, OpenSSL 3.5+ with ML-DSA), the exact
# image .github/workflows/ci.yml tests in. The runner is macula-pq-runtime
# from the same build (same Debian trixie date, so glibc and OpenSSL 3.5
# match the builder's). Move all pins together.
ARG BUILDER_IMAGE="ghcr.io/macula-io/macula-ci-gleam:gleam118-20260925-1402@sha256:4a177d3012dea97fb310a6f037197b4cc4ef1e38dc96f1bf246b57585e913b67"
ARG RUNNER_IMAGE="ghcr.io/macula-io/macula-pq-runtime:20260923-1444@sha256:15a5501b7277804c5a62c93121d157773d1401d238a1bf630ef4b50fc2f1df09"

# =============================================================================
# BUILD STAGE
# =============================================================================
FROM ${BUILDER_IMAGE} AS builder

# The OTP release, asserted here because the image tag names a date, not a
# release. Gleam 1.18.1 is the pinned toolchain; anything else is drift.
RUN erl -noshell -eval ' \
    Otp = string:trim(element(2, file:read_file(filename:join([code:root_dir(), "releases", erlang:system_info(otp_release), "OTP_VERSION"])))), \
    Mldsa = lists:member(mldsa87, crypto:supports(public_keys)), \
    io:format("OTP ~s, mldsa87 ~p~n", [Otp, Mldsa]), \
    case {Otp, Mldsa} of \
        {<<"28.4.3">>, true} -> halt(0); \
        _                    -> halt(1) \
    end.' \
    && gleam --version | grep -qx "gleam 1.18.1"

WORKDIR /build

# macula's QUIC NIF is compiled from source against this OTP, never fetched
# precompiled for another one.
ENV MACULA_FORCE_SOURCE_BUILD=1

# Dependencies resolve from gleam.toml alone, so these layers survive every
# change to src/ and config/. Referenced, not just declared: an ARG only
# invalidates a layer whose own instruction uses it, and every dependency
# resolves through a loose constraint, so a rebuild on unchanged sources must
# still run a real deps download.
COPY gleam.toml ./
COPY rebar.config ./
COPY scripts ./scripts
COPY priv ./priv
COPY config ./config
COPY src ./src
ARG CACHE_BUST=unknown
RUN echo "cache_bust=${CACHE_BUST}" > /dev/null

RUN gleam deps download
RUN gleam build
RUN scripts/release.sh

# =============================================================================
# RUNTIME STAGE
# =============================================================================
FROM ${RUNNER_IMAGE}

# LINKS THE PACKAGE TO THE REPOSITORY, so ghcr shows it there and it inherits
# the repository's visibility.
LABEL org.opencontainers.image.source="https://github.com/macula-services/mcl-bookclub-gleam"
# The commit this image was built from (build-push passes github.sha), so a
# digest a fleet pins can be traced back to its commit.
ARG REVISION=unknown
LABEL org.opencontainers.image.revision="${REVISION}"

# The runtime image carries what the release loads: libstdc++ and libgcc for
# the NIFs, OpenSSL 3 for OTP's crypto, ncurses, CA certificates, and curl for
# the health check.
WORKDIR /app
RUN useradd --create-home --shell /bin/bash app

# Must EXIST in the image, owned by app: a freshly created named volume takes
# its content and ownership from the path it is mounted over, so a path missing
# here becomes a root-owned volume the release cannot write.
#   /var/lib/mcl-bookclub-gleam   the club store (reckon-db) and read model
#   /etc/mcl/secrets              the node identity key
RUN mkdir -p /var/lib/mcl-bookclub-gleam /etc/mcl/secrets && \
    chown -R app:app /var/lib/mcl-bookclub-gleam /etc/mcl/secrets

COPY --from=builder --chown=app:app /build/_build/release/mcl_bookclub_gleam ./

USER app

ENV HOME=/app
ENV RELX_REPLACE_OS_VARS=true

ENV MCL_NODE_NAME=mcl_bookclub_gleam
ENV MCL_NODE_HOST=127.0.0.1
ENV MCL_COOKIE=mcl_bookclub_gleam
ENV MCL_HEALTH_PORT=8455
# The LAN admin UI, on its own port -- NOT a health port. Provisional until
# Terra confirms it (PORTS.md).
ENV MCL_ADMIN_PORT=8490
# The reckon-db store and the sqlite read model. A bind mount on a bulk drive;
# without one every recreate forgets the club's record.
ENV MCL_DATA_DIR=/var/lib/mcl-bookclub-gleam
# The node's identity key, on the mounted secrets volume: the observer pins
# its verification to this node's id, so the id must survive restarts.
ENV MCL_IDENTITY_KEY_PATH=/etc/mcl/secrets/identity.key

VOLUME ["/var/lib/mcl-bookclub-gleam", "/etc/mcl/secrets"]

EXPOSE 8455 8490
HEALTHCHECK --interval=30s --timeout=5s --start-period=30s --retries=3 \
    CMD curl -fsS "http://127.0.0.1:${MCL_HEALTH_PORT}/health" || exit 1

CMD ["/app/bin/mcl_bookclub_gleam", "foreground"]
