# wgcf-connector
Extract Cloudflare [WARP Connector](https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/private-net/warp-connector/) WireGuard configuration.

Cloudflare WARP is an overlay network like ZeroTier and Tailscale but instead of peer-to-peer, you connect to the nearest Cloudflare PoP using WireGuard just like NordVPN Meshnet.\
Finally, a free site-to-site VPN from Cloudflare.

This program uses the `warp-cli` Linux client, installs it inside the Docker container, register WARP Connector with the token, and then extract the configuration file.

## Usage
1. Make sure you have a [device profile](https://one.dash.cloudflare.com/?to=/:account/team-resources/devices/profiles) [set to WireGuard for the WARP Connector](https://www.animmouse.com/p/setup-cloudflare-warp-connector-using-wireguard/#create-a-separate-device-profile-for-warp-connector).
2. [Create a tunnel](https://one.dash.cloudflare.com/?to=/:account/networks/connectors/cloudflare-tunnels/add/warp) in Cloudflare Zero Trust dashboard with WARP Connector as tunnel type.
3. Copy the generated WARP Connector token starting with `eyJhIjoi` and paste it as argument `<token>` in Docker.
4. It will output wgcf-connector-<registration_id>.conf file in your current working directory, which you can use in WireGuard.

> [!TIP]
> If you got an endpoint IPv4 address starting with `162.159.192.x`, use `162.159.193.x` instead to have lower latency.

> [!TIP]
> You can check out my complete tutorial [here](https://www.animmouse.com/p/setup-cloudflare-warp-connector-using-wireguard/).

### Pull image remotely
> [!TIP]
> You can use GitHub Codespaces for this.
```
docker run --rm -v $(pwd):/app/output ghcr.io/animmouse/wgcf-connector <token>
```

### Build image locally
```
docker build -t wgcf-connector .
docker run --rm -v $(pwd):/app/output wgcf-connector <token>
```