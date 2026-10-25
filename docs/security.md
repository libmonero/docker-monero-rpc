# Security

## Published ports

Docker publishes `-p 18081:18081` on all interfaces, and its rules are applied before the ones of UFW, so a port can be reachable from the internet even if UFW denies it. Publish the rpc to localhost:

* `docker run`: `-p 127.0.0.1:18081:18081`
* compose: `"127.0.0.1:18081:18081"`

Publish the p2p port only if the node is meant to be reachable.

## RPC

Set `--rpc-login` on the rpc of the daemon and of the wallet, and do not expose them to the internet. A public node should only serve the restricted rpc, see the example in [usage](usage.md#monero-daemon-rpc).

## Hardening

The containers run as uid 1000 and need no capability, no write access outside of their volumes and no new privileges. Both images are tested in CI with these options:

```bash
docker run -d --read-only --cap-drop ALL --security-opt no-new-privileges ...
```

In compose:

```yaml
read_only: true
cap_drop: [ALL]
security_opt: ["no-new-privileges:true"]
```

With a read only root the wallet needs `--log-file=/dev/null`, as it writes its log in the home directory.

## Licenses

The images contain the license of monero-project and the one of this repository, in `/usr/share/licenses`.
