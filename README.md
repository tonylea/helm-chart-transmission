# Transmission Helm Chart

![Downloads](https://img.shields.io/github/downloads/tonylea/helm-chart-transmission/total)

Deploys [Transmission](https://transmissionbt.com/) behind [Gluetun](https://github.com/qdm12/gluetun), the VPN client, in one pod.
Transmission uses LinuxServer's image, [`lscr.io/linuxserver/transmission`](https://github.com/linuxserver/docker-transmission), because the project publishes none, and LinuxServer's applies the RPC login from the environment and documents running non-root.
Gluetun uses the project's own image, [`ghcr.io/qdm12/gluetun`](https://github.com/qdm12/gluetun).

The chart is opinionated: Transmission's traffic leaves the pod only through the VPN, because the two share a network namespace and Gluetun's firewall blocks everything else.
It runs one replica, and stops the old pod before starting the new one, since Transmission's state can't be shared.
Transmission keeps its settings and resume files on a `/config` volume, partial downloads on an incomplete volume, and finished downloads on one or more shared media volumes.

## Values

| Value | Default |
| --- | --- |
| `image.tag` | the chart's `appVersion` (Transmission and the port-sync sidecar) |
| `puid` | `1000` |
| `pgid` | `1000` |
| `timezone` | `UTC` |
| `gluetun.image.tag` | `v3.41.3` |
| `gluetun.env` | none; required, a map of Gluetun's provider settings |
| `gluetun.wireguardPrivateKey.secretKeyRef.name` | none; required |
| `gluetun.wireguardPrivateKey.secretKeyRef.key` | `wireguard-private-key` |
| `gluetun.firewallOutboundSubnets` | none; required |
| `gluetun.startupProbe` | Gluetun's health check |
| `gluetun.readinessProbe` | Gluetun's health check |
| `gluetun.resources` | none |
| `auth.username.secretKeyRef.name` | none; required |
| `auth.username.secretKeyRef.key` | `username` |
| `auth.password.secretKeyRef.name` | none; required |
| `auth.password.secretKeyRef.key` | `password` |
| `downloadDir` | none; required, the default download directory, inside a media mount |
| `downloadQueueSize` | `2` |
| `resources` | none |
| `portSync.resources` | none |
| `persistence.config.existingClaim` | none; required |
| `persistence.incomplete.existingClaim` | none; required |
| `persistence.incomplete.chown` | `true`; set `false` where the storage refuses a chown, such as an NFS export that maps every user to one |
| `persistence.media` | none; at least one mount required |
| `persistence.media[].name` | required |
| `persistence.media[].existingClaim` | required |
| `persistence.media[].mountPath` | required |
| `httpRoute.enabled` | `false` |
| `httpRoute.parentRefs` | none; required when enabled |
| `httpRoute.hostnames` | none |

## Fixed settings

The init container sets these in `settings.json` at every start, so they can't be changed in the web UI:

- `download-dir`, from `downloadDir`.
  Each client that adds a torrent can still send its own directory.
- `incomplete-dir`, the incomplete volume, and `incomplete-dir-enabled`, always on.
- `download-queue-size`, from `downloadQueueSize`.

The init container runs before Transmission starts because Transmission rewrites `settings.json` when it exits.
The image's own start then applies the RPC login from the environment.
The RPC and host whitelists stay off.

The pod's containers are set up as follows:

- Gluetun is a native sidecar, so Transmission starts only once its startup probe passes, which is when the tunnel is up.
  It runs as root with `NET_ADMIN`, and allows inbound traffic on port 9091 only.
  Its health check is the readiness probe too, so the pod leaves the Service while the VPN is down.
  It has no liveness probe: Gluetun restarts the VPN itself, and killing the container would leave stale IP rules in the pod, which its `postStart` clears.
- The port-sync sidecar reads the port Gluetun forwards, if the provider settings turn port forwarding on, and sets it as Transmission's peer port with `transmission-remote` whenever it changes.
- Transmission and the sidecar run in LinuxServer's non-root mode, as `puid` and `pgid`, with all capabilities dropped.
  The image no longer fixes volume ownership in this mode, so every claim must be writable by that user.

## Requirements

- A Secret holding Gluetun's WireGuard private key, and one holding Transmission's RPC username and password.
  The port-sync sidecar uses the same login.
- Existing claims for `/config`, the incomplete folder, and each media mount.
  Each media mount is mounted at its `mountPath`, so a client that sends a download directory finds the same path as in the pod that reads it.
  `/config` and the incomplete claim need `ReadWriteOnce` at least.
- On a node whose kernel has no WireGuard, Gluetun falls back to a userspace implementation that needs `/dev/net/tun`, which this chart doesn't provide.
- The Gateway API's `HTTPRoute` CRD, when `httpRoute.enabled` is set.

## Usage

```sh
helm repo add transmission https://tonylea.github.io/helm-chart-transmission
helm install transmission transmission/transmission --values my-values.yaml
```

```yaml
timezone: Europe/London
gluetun:
  env:
    VPN_SERVICE_PROVIDER: protonvpn
    VPN_TYPE: wireguard
    VPN_PORT_FORWARDING: "on"
  wireguardPrivateKey:
    secretKeyRef:
      name: gluetun
  firewallOutboundSubnets: 10.0.0.0/8
auth:
  username:
    secretKeyRef:
      name: transmission
  password:
    secretKeyRef:
      name: transmission
downloadDir: /media/downloads
persistence:
  config:
    existingClaim: transmission-config
  incomplete:
    existingClaim: transmission-incomplete
  media:
    - name: media
      existingClaim: media
      mountPath: /media
```

## Development

Pull requests run:

- `helm lint --strict`, and the rendered chart checked by kubeconform against Kubernetes 1.37.
- helm-unittest's tests in `tests/`.
- An install with chart-testing in a kind cluster, against the Secrets and claims from `ci/kind`.
  No VPN server answers there, so `ci/kind-values.yaml` replaces Gluetun's probes.

Commits follow Conventional Commits.
Releases are versioned and tagged automatically from `main`, and published to the Helm repository on this repo's GitHub Pages.
