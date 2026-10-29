# Usage

The images take the arguments of `monerod`, `monero-wallet-rpc` and `monero-lws-daemon`. Nothing is set by default, except `--non-interactive` in the daemon. Everything can also be set in a config file.

Compose files for a node with a wallet and for tests are in [examples](../examples). They take the image tag from `MONERO_TAG`, in the environment or in a `.env` file next to the compose file, for example `MONERO_TAG=v0.18.5.1-1 docker compose -f examples/docker-compose.yml up -d`.

## monero-daemon-rpc

Run a stagenet node, with its rpc published to localhost only:

```bash
docker run -d --name monerod -v monerod_data:/home/monero/.bitmonero \
  -p 38080:38080 -p 127.0.0.1:38081:38081 \
  ghcr.io/libmonero/monero-daemon-rpc:latest \
  --stagenet --no-igd --rpc-bind-ip=0.0.0.0 --rpc-bind-port=38081 \
  --confirm-external-bind --rpc-login=superuser:abctesting123
```

A public mainnet node, pruned and with the restricted rpc:

```bash
docker run -d --name monerod -v monerod_data:/home/monero/.bitmonero \
  -p 18080:18080 -p 18089:18089 \
  ghcr.io/libmonero/monero-daemon-rpc:latest \
  --no-igd --prune-blockchain --enable-dns-blocklist --public-node \
  --rpc-restricted-bind-ip=0.0.0.0 --rpc-restricted-bind-port=18089 --confirm-external-bind
```

## monero-wallet-rpc

`--rpc-bind-port`, `--rpc-login` (or `--disable-rpc-login`) and `--wallet-dir` or `--wallet-file` are required. Wallets are kept in `/home/monero/wallets`:

```bash
docker run -d --name monero-wallet-rpc -v wallets:/home/monero/wallets \
  -p 127.0.0.1:38083:38083 \
  ghcr.io/libmonero/monero-wallet-rpc:latest \
  --stagenet --daemon-address=monerod:38081 --daemon-login=superuser:abctesting123 \
  --rpc-bind-ip=0.0.0.0 --rpc-bind-port=38083 --confirm-external-bind \
  --rpc-login=rpc_user:abc123 --wallet-dir=/home/monero/wallets --log-file=/dev/null
```

Both containers have to be on the same user defined network to reach each other by name, which compose does by default.

Create a wallet:

```bash
curl --digest -u rpc_user:abc123 http://127.0.0.1:38083/json_rpc -H 'Content-Type: application/json' \
  -d '{"jsonrpc":"2.0","id":"0","method":"create_wallet","params":{"filename":"wallet","password":"abc123","language":"English"}}'
```

The wallet takes `--stagenet` and `--testnet`. For a regtest daemon, start the wallet without a network flag.

## monero-wallet-light

The light wallet server, [monero-lws](https://github.com/vtnerd/monero-lws), follows a node through its zmq rpc and its zmq pub, so the node has to publish both. The rest server is on `https://0.0.0.0:8443` unless `--rest-server` says otherwise, the database is kept in `/home/monero/.bitmonero`:

```bash
docker run -d --name monero-lws -v lws_data:/home/monero/.bitmonero \
  -p 127.0.0.1:8443:8443 \
  ghcr.io/libmonero/monero-wallet-light:latest \
  --daemon=tcp://monerod:38082 --sub=tcp://monerod:38083 \
  --rest-server=http://0.0.0.0:8443 --confirm-external-bind
```

The node needs `--zmq-rpc-bind-ip=0.0.0.0 --zmq-rpc-bind-port=38082 --zmq-pub=tcp://0.0.0.0:38083`, with `--confirm-zmq-rpc-external-bind` when it is not on localhost. A regtest node takes `--regtest` in the light wallet server too, see the [compose file](../examples/regtest/docker-compose.yml).

`monero-lws-admin` is in the same image, run it in the container:

```bash
docker exec monero-lws monero-lws-admin list_accounts
```

`--admin-rest-server` serves the admin api, and `--disable-admin-auth` leaves it without keys, only for tests.

## Ports

| Network | p2p | rpc | zmq rpc |
|---------|-----|-----|---------|
| mainnet | `18080` | `18081` | `18082` |
| testnet | `28080` | `28081` | `28082` |
| stagenet | `38080` | `38081` | `38082` |

`monero-wallet-rpc` has no default port, `--rpc-bind-port` is required. `monero-wallet-light` has its rest server on `8443`, and the admin one, with `--admin-rest-server`, on a port of choice, `8444` in the examples. The examples use `38083` on stagenet and `18082` to `18084` in the tests. The restricted rpc of a public node is on `--rpc-restricted-bind-port`, `18089` in the examples. The ports of the images are only documentation, they are published with `-p` or `ports:`.

## Config file

Mount a config file and pass it with `--config-file`:

```bash
docker run -d --name monerod -v monerod_data:/home/monero/.bitmonero \
  -v "$PWD/monerod.conf:/etc/monerod.conf:ro" \
  ghcr.io/libmonero/monero-daemon-rpc:latest --config-file=/etc/monerod.conf
```

```
stagenet=1
no-igd=1
rpc-bind-ip=0.0.0.0
rpc-bind-port=38081
confirm-external-bind=1
rpc-login=superuser:abctesting123
```

`bitmonero.conf` in the data directory is read without `--config-file`, as it is in any monerod. The command line has priority over the file.

## Data and permissions

The containers run as `monero`, uid 1000. Volumes have to be mounted on the paths of the image, `/home/monero/.bitmonero` (the daemon and the light wallet server) and `/home/monero/wallets`, which are owned by that user. A volume on any other path is owned by root and cannot be written, `monero-wallet-rpc` fails with `failed to save file "/wallet/wallet.keys"`.

A named volume is fine. A host directory has to be owned by uid 1000, or the container started with the uid that owns it:

```bash
docker run -d --user "$(id -u):$(id -g)" -v "$PWD/data:/home/monero/.bitmonero" \
  ghcr.io/libmonero/monero-daemon-rpc:latest --stagenet
```

A directory owned by root, which is what Docker creates for a missing host path, makes the daemon exit with `Permission denied` creating `/home/monero/.bitmonero/stagenet`.

## Healthcheck

The images have one. It reads the rpc port, the network and `rpc-login` from the arguments or from the config file, so it follows whatever configuration is used, and calls `/get_height` on the daemon, `get_version` on the wallet and `/get_version` of the rest server on the light wallet server. A `401` is accepted when the login is not where it can read it. The state is in `docker ps` and `docker inspect`, and the interval can be changed with the `--health-*` options.

## Logs

The wallet also writes `monero-wallet-rpc.log` in `/home/monero`. `--log-file=/dev/null` leaves the logs in the container output only, and is needed with `--read-only`.

Docker keeps the container output without a limit. The compose examples rotate it with `max-size: 50m` and `max-file: 5`, with `docker run` use `--log-opt max-size=50m --log-opt max-file=5`.
