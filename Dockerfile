FROM debian:13-slim
LABEL org.opencontainers.image.source="https://github.com/AnimMouse/wgcf-connector"
WORKDIR /app
ARG DEBIAN_FRONTEND=noninteractive
RUN apt-get -qq update && apt-get -qq install --no-install-recommends ca-certificates dbus jq && rm -rf /var/lib/apt/lists/* && mkdir /run/dbus /app/output
ADD --chmod=644 https://pkg.cloudflareclient.com/pubkey.gpg /usr/share/keyrings/cloudflare-warp-archive-keyring.asc
ARG VERSION=2026.7.1377.0
RUN echo "deb [signed-by=/usr/share/keyrings/cloudflare-warp-archive-keyring.asc] https://pkg.cloudflareclient.com/ trixie main" > /etc/apt/sources.list.d/cloudflare-client.list && \
    apt-get -qq update && apt-get -qq install --no-install-recommends cloudflare-warp=$VERSION && rm -rf /var/lib/apt/lists/*
COPY wgcf-connector.sh .
ENTRYPOINT [ "/app/wgcf-connector.sh" ]