# Handoff

Working notes for continuing this work after a dev container rebuild. Last updated 2026-10-01.

## Where things stand

- `.devcontainer/devcontainer.json` added and committed (`87c2571`, not yet pushed). It provides Docker-in-Docker, `gh`, Node and Claude Code, and a persistent `~/.claude` volume. The container has not been rebuilt with it yet.
- No code fixes have been made yet. Versioning comes first (see below).
- The repo has **no git tags**. `ghcr.io/animmouse/wgcf-connector:latest` has about 2k pulls.
- The current `:latest` digest is `sha256:6d295244eaafcedb4343d9eaac545262b60231ae9aa0f069ffeb55dc36f01a4a` (single-arch amd64, inspected 2026-09-25). It should correspond to commit `5b4fe17`; check that build succeeded in the Actions tab before tagging.

## Next steps, in order

### 1. Semantic versioning (do this before any fixes)

Decisions so far:

- **Don't freeze `:latest`.** It should keep tracking the newest stable release, so users get fixes and WARP bumps. Old WARP clients may eventually be rejected by Cloudflare.
- **Mark the current state as v1.0.0 by retagging the existing image, not rebuilding it**, so the bytes stay identical:
  ```sh
  gh auth login --scopes write:packages
  gh auth token | docker login ghcr.io -u AnimMouse --password-stdin
  img=ghcr.io/animmouse/wgcf-connector
  docker buildx imagetools create -t $img:1.0.0 -t $img:1.0 -t $img:1 $img:latest
  git tag -a v1.0.0 5b4fe17 -m "v1.0.0" && git push origin v1.0.0
  ```
- **The fixes are v1.0.x or v1.1.0, not v2.** They don't change the interface (the `<token>` argument, the `/app/output` mount, the `wgcf-connector-<id>.conf` filename). Save v2 for a real interface break.

Still to do:

- [ ] Retag v1.0.0 (commands above) and create a GitHub release.
- [ ] Update `build-and-push.yaml`: pushing a `v*` tag publishes `:X.Y.Z`, `:X.Y`, `:X` and `:latest` (use `docker/metadata-action`). Pushes to `main` publish only `:edge`. Add the OCI `revision` label.
- [ ] **Open decision:** how WARP auto-bumps are versioned. Recommended: `auto-update.yaml` cuts a patch release automatically (v1.0.1, v1.0.2, …) so every image has an immutable version. The alternative is rebuilding the floating tags in place.
- [ ] Explain the tags in the README: `:latest` for most users, `:1` to stay on major version 1, `:1.0.0` to pin exactly.

### 2. Fixes (release as v1.0.1+)

Guiding principle: you don't need to handle every error path, but the tool must never report success when it failed. Fail fast, validate values once before writing, and prioritize silent failures and anything that runs unattended.

Latent bugs, highest priority first:

- [ ] **`wgcf-connector.sh`: errors inside the heredoc are ignored.** `set -e` doesn't stop on a failing `$(...)` inside a heredoc (verified in dash and bash), and `jq -r` prints `null` for missing fields. The result can be `PrivateKey = ` or `Endpoint = null` with exit 0. Fix: read each value once with `jq -er` into variables, check they're non-empty and not `null`, then write the file.
- [ ] **`wgcf-connector.sh`: `sleep 5s` is a race.** Poll instead, with a timeout:
  `until warp-cli --accept-tos status` for daemon readiness, then `until jq -e .public_key conf.json` after `connector new`.
- [ ] **`auto-update.yaml`: can commit `ARG VERSION=`.** If `curl -s` fails, the version is empty and a broken Dockerfile gets committed. Fix: use `curl -fsS` and check the version is non-empty before `sed`.
- [ ] **The MASQUE check runs after the `.conf` is written**, leaving an unusable file behind. Move it before the write.

Hardening:

- [ ] Add `umask 077` and `chown "$(stat -c %u:%g /app/output)"` on the output file. It currently ends up `root:root 644` and contains the private key.
- [ ] Print a usage message when no token is given; `set -u` currently gives a cryptic error.
- [ ] Generate the extra endpoint lines with one jq expression over `.endpoints[]`, so a missing endpoint doesn't produce `null`.
- [ ] The hard-coded peer public key check (`bmXOC+F1…`) breaks if Cloudflare rotates the key. Check the tunnel protocol field in `conf.json` if one exists, or change the error message to "unexpected peer key, possibly MASQUE".

Polish:

- [ ] Build arm64 too (`buildx --platform linux/amd64,linux/arm64`). Cloudflare publishes a trixie arm64 package at the same version.
- [ ] Replace `wget` with `ADD https://pkg.cloudflareclient.com/pubkey.gpg …`, and replace `| tee` with `>`.
- [ ] Use `warp-svc` consistently instead of mixing it with `/bin/warp-svc`.

### 3. New repo `wgcf-mesh`: call the registration API directly

Goal: generate the Mesh WireGuard config without Docker or the WARP client, the way ViRb3/wgcf and poscat0x04/wgcf-teams do. This repo stays as the Docker-based fallback.

Decisions:

- **Bash first** (`curl`, `jq`, and `wg genkey` or `openssl genpkey -algorithm X25519`; macOS LibreSSL may lack X25519, so fall back to `wg`). Not Go or Rust.
- **Browser app only if CORS allows it.** Check with `curl -i -X OPTIONS -H 'Origin: https://example.com' <endpoint>`. If a proxy would be needed, don't build it, because every user's Mesh token would pass through our server.
- Document the protocol in **`API.md`**. Bash is the canonical implementation.
- Add a scheduled CI smoke test using a dedicated test token.

Reverse-engineering plan (use a **throwaway** Mesh token and delete the node afterwards):

1. Decode the token with `base64 -d`. It's JSON starting with `{"a":…`, probably an account ID plus a secret; unverified.
2. Read the `warp-svc` debug logs under `/var/log/cloudflare-warp/`.
3. Run `strings` on the `warp-svc` binary to find API paths and `CF-…` headers.
4. Intercept traffic with mitmproxy in the container. Risk: `warp-svc` is written in Rust and may use a bundled trust store or certificate pinning.
5. Replay with curl and a fresh keypair, and compare the response with a real `conf.json`.

What we already know: `reg.json` (containing `secret_key` and `registration_id`) shows the keypair is generated locally, and `conf.json` has the response (interface addresses, peer key, endpoints). The request is the unknown part.

Risks: the API is undocumented and can change without notice. Read Cloudflare's terms before publishing.

## Environment notes

- The container this was written in was not privileged, so `dockerd` could only run with `--iptables=false --bridge=none --storage-driver=vfs`, and `docker run` failed with `unshare: operation not permitted`. Registry commands worked. The new devcontainer (DinD, privileged) should fix this. Codespaces works the same way: a privileged container in a dedicated VM.
- If DinD isn't acceptable on a shared host, the options are Docker-outside-of-Docker (but `-v $(pwd)` then resolves on the host) or Sysbox.
