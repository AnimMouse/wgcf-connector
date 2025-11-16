FROM debian:12-slim
LABEL org.opencontainers.image.source="https://github.com/AnimMouse/wgcf-connector"
WORKDIR /app
ARG DEBIAN_FRONTEND=noninteractive
RUN apt-get -qq update && apt-get -qq install --no-install-recommends wget ca-certificates dbus jq && rm -rf /var/lib/apt/lists/* && mkdir /run/dbus /app/output
ARG VERSION=2025.9.558.0
RUN wget -O /usr/share/keyrings/cloudflare-warp-archive-keyring.asc https://pkg.cloudflareclient.com/pubkey.gpg && \
    echo "deb [signed-by=/usr/share/keyrings/cloudflare-warp-archive-keyring.asc] https://pkg.cloudflareclient.com/ bookworm main" | tee /etc/apt/sources.list.d/cloudflare-client.list && \
    apt-get -qq update && apt-get -qq install --no-install-recommends cloudflare-warp=$VERSION && rm -rf /var/lib/apt/lists/*
COPY wgcf-connector.sh .
ENTRYPOINT [ "/app/wgcf-connector.sh" ]