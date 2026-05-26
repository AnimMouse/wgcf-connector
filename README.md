# wgcf-connector
Extract [Cloudflare Mesh](https://developers.cloudflare.com/cloudflare-one/networks/connectors/cloudflare-mesh/) (formerly WARP Connector) WireGuard configuration.

Cloudflare Mesh is an overlay network like ZeroTier and Tailscale but instead of peer-to-peer, you connect to the nearest Cloudflare PoP using WireGuard just like NordVPN Meshnet.\
Finally, a free site-to-site VPN from Cloudflare.

This program uses the `warp-cli` Linux client, installs it inside the Docker container, register Cloudflare Mesh with the token, and then extract the configuration file.

## Usage
1. Make sure you have a [device profile](https://dash.cloudflare.com/?to=/:account/one/team-resources/devices/profiles) [set to WireGuard for the Cloudflare Mesh node](https://www.animmouse.com/p/setup-cloudflare-mesh-using-wireguard/#create-a-separate-device-profile-for-the-cloudflare-mesh-nodes).
2. [Create a Mesh node](https://dash.cloudflare.com/?to=/:account/mesh) in Cloudflare dashboard.
3. Copy the generated Cloudflare Mesh token that starts with `eyJhIjoi` and ends with `In0=`, and paste it as argument `<token>` in Docker.
4. It will output wgcf-connector-<registration_id>.conf file in your current working directory, which you can use in WireGuard.

> [!TIP]
> If you got an endpoint IPv4 address starting with `162.159.192.x`, use `162.159.193.x` instead to have lower latency.

> [!TIP]
> You can check out my complete tutorial [here](https://www.animmouse.com/p/setup-cloudflare-mesh-using-wireguard/).

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