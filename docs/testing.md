# Tests

The images can run the nodes and wallets of the tests of monero-cpp, monero-java, monero-python and monero-ts, which use a regtest network. The compose file in [examples/regtest](../examples/regtest/docker-compose.yml) has the same services and ports as the one of monero-python: two nodes connected to each other, three wallets and a light wallet server.

```bash
docker compose -f examples/regtest/docker-compose.yml up -d
```

| Service | Ports |
|---------|-------|
| node_1 | `48080` p2p, `18089` rpc |
| node_2 | `18080` p2p, `18081` rpc, `18085` zmq rpc, `18086` zmq pub |
| xmr_wallet_1, 2, 3 | `18082`, `18083`, `18084` |
| xmr_lws | `8443` rest, `8444` admin rest |

Logins are `rpc_daemon_user:abc123` for the nodes and `rpc_user:abc123` for the wallets. Set `MONERO_TAG` to a version tag, for example `MONERO_TAG=v0.18.5.1-1 docker compose ... up -d`, to keep the tests on the same Monero.

Blocks are created with the `generateblocks` rpc, which only exists in regtest, here mining 10 blocks to the first wallet:

```bash
address=$(curl -s --digest -u rpc_user:abc123 http://127.0.0.1:18082/json_rpc \
  -H 'Content-Type: application/json' -d '{"jsonrpc":"2.0","id":"0","method":"get_address"}' | grep -o '"address": *"[^"]*"' | head -1 | cut -d'"' -f4)

curl --digest -u rpc_daemon_user:abc123 http://127.0.0.1:18081/json_rpc -H 'Content-Type: application/json' \
  -d "{\"jsonrpc\":\"2.0\",\"id\":\"0\",\"method\":\"generateblocks\",\"params\":{\"wallet_address\":\"$address\",\"amount_of_blocks\":10}}"
```

The wallet has to be created first, with `create_wallet` as in [usage](usage.md#monero-wallet-rpc). The blocks reach node_1 through the p2p connection between the nodes. The first call can take more than a minute on a slow machine.

## Functional tests

The [Test](../.github/workflows/test.yml) workflow waits for [Build](../.github/workflows/build.yml) and runs the python functional tests of monero-project against the binaries it built, on `linux/amd64` and `linux/arm64`. Run it by hand from the Actions tab with the id of a Build run and a list of tests.

The same tests run locally on the images of `make build`:

```bash
make build
make functional TESTS="daemon_info wallet"
```

Without `TESTS` it runs all the tests but four, which takes about 15 minutes. `validate_address` and `address_book` look up openalias addresses, which needs a resolver with dnssec and the runners do not have one, `mining` and `rpc_payment` need helpers that are not built here. The tests start 4 nodes and 6 wallets in regtest and each node that verifies blocks uses about 2.4 GB of memory, so keep the full list for a machine with 16 GB. Needs `python3` with `venv`.

## monero-wallet-light

The build of the image runs the unit tests of monero-lws, and [lws_test.sh](../bin/lws_test.sh) starts a node, a wallet and the light wallet server from the images of `make build`, mines blocks and waits for the light wallet server to scan up to the top of the chain, `make test` runs it. It also listens to the zmq pub of the node, for new blocks, and to the one of the light wallet server, for the payments of the account, with [pyzmq](https://pyzmq.readthedocs.io), so it needs `python3` with `venv`. A regtest chain is used by the default variant, and a testnet one by `private-testnet`: it is mined past the hardfork at height 150, the last of its schedule.

## From lalanza808/monero

What changes in a compose file that uses `lalanza808/monero`:

* The `command` has no `monerod` or `monero-wallet-rpc` first, the entrypoint is the binary.
* The daemon has no `--non-interactive`, it is in the entrypoint and repeating it is an error. The wallet accepts it.
* Volumes go on `/home/monero/.bitmonero` and `/home/monero/wallets` instead of `/data` and `/wallet`, see [usage](usage.md#data-and-permissions).
* The wallets take no `--regtest`, only the nodes do.
* `monero-lws` is the `monero-wallet-light` image, the entrypoint is `monero-lws-daemon` and `monero-lws-admin` is in the image.

For a network with the hardforks at low heights instead of regtest, see [private testnet](private-testnet.md).
