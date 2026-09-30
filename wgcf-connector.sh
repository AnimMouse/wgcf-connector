#!/bin/sh
set -eu

state=/var/lib/cloudflare-warp
output=/app/output

die() {
  echo "Error: $*" >&2
  exit 1
}

# Run a command every second until it succeeds, for up to $1 seconds.
retry() {
  n=$1
  shift
  until "$@" > /dev/null 2>&1; do
    n=$((n - 1))
    [ "$n" -gt 0 ] || return 1
    sleep 1
  done
}

# Print a string field from a JSON file, failing if it is missing, null or empty.
field() {
  jq -er "$2 | strings | select(. != \"\")" "$state/$1" || die "$2 missing from $1"
}

if [ $# -ne 1 ]; then
  echo "Usage: docker run --rm -v \"\$(pwd):$output\" ghcr.io/animmouse/wgcf-connector <token>" >&2
  exit 2
fi
mountpoint -q "$output" || die "$output is not mounted, the configuration would be lost. Add -v \"\$(pwd):$output\"."

dbus-daemon --system
warp-svc > /dev/null 2>&1 &
retry 30 warp-cli --accept-tos status || die "warp-svc did not start"
warp-cli --accept-tos connector new "$1"
# The client registers with MASQUE keys, then switches keys to match the device profile.
retry 30 jq -e '.tunnel_key_data.tunnel_type == .policy.tunnel_protocol' "$state/conf.json" ||
  die "registration did not complete"

protocol=$(field conf.json .policy.tunnel_protocol)
[ "$protocol" = wireguard ] ||
  die "Tunnel protocol is $protocol instead of wireguard. Make sure you have a device profile set to WireGuard."

id=$(field reg.json '.registration_id[0]')
private_key=$(field reg.json .secret_key)
[ "$(printf %s "$private_key" | base64 -d 2> /dev/null | wc -c)" -eq 32 ] || die "secret_key in reg.json is not a WireGuard key"
public_key=$(field conf.json .public_key)
organization=$(field conf.json .account.organization)
v4=$(field conf.json .interface.v4)
v6=$(field conf.json .interface.v6)
endpoint=$(field conf.json '.endpoints[0].v4')
other_endpoints=$(jq -r '[.endpoints[] | .v4, .v6 | strings] | .[1:][] | "#Endpoint = \(.)"' "$state/conf.json")

file=$output/wgcf-connector-$id.conf
umask 077
cat > "$file" << EOL
# Registration ID: $id
# Organization: $organization
[Interface]
PrivateKey = $private_key
Address = $v6/128, $v4/32
DNS = 2606:4700:4700::1111, 2606:4700:4700::1001, 1.1.1.1, 1.0.0.1
MTU = 1420

[Peer]
PublicKey = $public_key
AllowedIPs = ::/0, 0.0.0.0/0
Endpoint = $endpoint
$other_endpoints
EOL
chown "$(stat -c %u:%g "$output")" "$file" || echo "Warning: could not change the owner of $file" >&2
echo "Saved $file"
