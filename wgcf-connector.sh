#!/bin/sh
set -eu
dbus-daemon --system
/bin/warp-svc &
sleep 5s
warp-cli --accept-tos connector new "$1"
sleep 5s
cat > /app/output/wgcf-connector-$(jq -r .registration_id[0] < /var/lib/cloudflare-warp/reg.json).conf << EOL
# Registration ID: $(jq -r .registration_id[0] < /var/lib/cloudflare-warp/reg.json)
# Organization: $(jq -r .account.organization < /var/lib/cloudflare-warp/conf.json)
[Interface]
PrivateKey = $(jq -r .secret_key < /var/lib/cloudflare-warp/reg.json)
Address = $(jq -r .interface.v6 < /var/lib/cloudflare-warp/conf.json)/64, $(jq -r .interface.v4 < /var/lib/cloudflare-warp/conf.json)/12
DNS = 2606:4700:4700::1111, 2606:4700:4700::1001, 1.1.1.1, 1.0.0.1
MTU = 1420

[Peer]
PublicKey = $(jq -r .public_key < /var/lib/cloudflare-warp/conf.json)
AllowedIPs = ::/0, 0.0.0.0/0
Endpoint = $(jq -r .endpoints[0].v4 < /var/lib/cloudflare-warp/conf.json)
#Endpoint = $(jq -r .endpoints[0].v6 < /var/lib/cloudflare-warp/conf.json)

#Endpoint = $(jq -r .endpoints[1].v4 < /var/lib/cloudflare-warp/conf.json)
#Endpoint = $(jq -r .endpoints[1].v6 < /var/lib/cloudflare-warp/conf.json)
#Endpoint = $(jq -r .endpoints[2].v4 < /var/lib/cloudflare-warp/conf.json)
#Endpoint = $(jq -r .endpoints[2].v6 < /var/lib/cloudflare-warp/conf.json)
#Endpoint = $(jq -r .endpoints[3].v4 < /var/lib/cloudflare-warp/conf.json)
#Endpoint = $(jq -r .endpoints[3].v6 < /var/lib/cloudflare-warp/conf.json)
EOL
if [ "$(jq -r .public_key < /var/lib/cloudflare-warp/conf.json)" != "bmXOC+F1FxEMF9dyiK2H5/1SUtzH0JuVo51h2wPfgyo=" ]; then
  echo "Error: Got MASQUE instead of WireGuard. Make sure you have a device profile set to WireGuard."
  exit 1
fi