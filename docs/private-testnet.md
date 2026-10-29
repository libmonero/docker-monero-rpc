# Private testnet

The `private-testnet` variant of the images is built with [patches/private-testnet.patch](../patches/private-testnet.patch), which schedules the testnet hardforks at low block heights instead of the real ones. A private testnet reaches the latest consensus rules after 150 blocks instead of two million.

It is meant for local networks and CI of software that needs the current rules from the start, like wallets and libraries ([monero-cpp](https://github.com/woodser/monero-cpp), [monero-java](https://github.com/woodser/monero-java), [monero-python](https://github.com/everoddandeven/monero-python), [monero-ts](https://github.com/woodser/monero-ts)).

> [!WARNING]
> Nodes of this variant cannot sync the public testnet. They fork away from it at block 10 and the public testnet nodes reject their blocks. Mainnet and stagenet are not affected.

## Regtest or private testnet

* `--regtest` is a separate fake chain: all the hardforks are active from height 1 and blocks are created with the `generateblocks` rpc, which only exists there. It is the quickest choice for most tests and works with the default images.
* The private testnet is the `testnet` network with its usual ports (`28080` p2p, `28081` rpc) and addresses, where the hardforks happen along the chain, at the heights below. Use it when the software has to see a hardfork happen, or has to run on the testnet network type.

## Hardfork heights

| Version | Testnet | Private testnet |
|---------|---------|-----------------|
| 2 | 624634 | 10 |
| 3 | 800500 | 20 |
| 4 | 801219 | 30 |
| 5 | 802660 | 40 |
| 6 | 971400 | 50 |
| 7 | 1057027 | 60 |
| 8 | 1057058 | 70 |
| 9 | 1057778 | 80 |
| 10 | 1154318 | 90 |
| 11 | 1155038 | 100 |
| 12 | 1308737 | 110 |
| 13 | 1543939 | 120 |
| 14 | 1544659 | 130 |
| 15 | 1982800 | 140 |
| 16 | 1983520 | 150 |

## Usage

The variant is a normal image, everything is configured with arguments or a config file. Start a node on a private testnet, with a fixed difficulty so blocks are easy to mine:

```bash
docker run -d --name monerod -p 28081:28081 monero-daemon-rpc:private-testnet \
  --testnet --fixed-difficulty=500 --no-igd \
  --rpc-bind-ip=0.0.0.0 --rpc-bind-port=28081 --confirm-external-bind
```

Check that the node has the private schedule, the earliest height of version 16 is 150 (1983520 in the default images):

```bash
curl -s http://127.0.0.1:28081/json_rpc -H 'Content-Type: application/json' \
  -d '{"jsonrpc":"2.0","id":"0","method":"hard_fork_info","params":{"version":16}}'
```

`monero-wallet-rpc` has the variant too, because wallet2 reads the same table to tell if the wallet or the daemon is outdated. Start it with `--testnet`.

`monero-wallet-light` has the variant too, the light wallet server reads the same table to follow the blocks. Start it with `--testnet`.

`--version` is the same in both variants, as the version comes from the commit. The variant can be told from the image tag (`private-testnet-` prefix), from the `io.libmonero.variant` label, or with the rpc call above.

## Compose

[examples/private-testnet/docker-compose.yml](../examples/private-testnet/docker-compose.yml) has the same services and ports as the [regtest one](../examples/regtest/docker-compose.yml), two nodes connected to each other and three wallets, with `--testnet` and the `private-testnet` images. The nodes only connect to each other (`--add-exclusive-node`), they never reach the public testnet.

```bash
docker compose -f examples/private-testnet/docker-compose.yml up -d
```

`generateblocks` only exists in regtest, here the blocks are mined with `start_mining`, to the address of a wallet created with `create_wallet` as in [usage](usage.md#monero-wallet-rpc):

```bash
address=$(curl -s --digest -u rpc_user:abc123 http://127.0.0.1:18082/json_rpc \
  -H 'Content-Type: application/json' -d '{"jsonrpc":"2.0","id":"0","method":"get_address"}' | grep -o '"address": *"[^"]*"' | head -1 | cut -d'"' -f4)

curl --digest -u rpc_daemon_user:abc123 http://127.0.0.1:18081/start_mining \
  -d "{\"miner_address\":\"$address\",\"threads_count\":1,\"do_background_mining\":false,\"ignore_battery\":true}"
```

The `version` in the result of `hard_fork_info` goes to 2 at height 10 and to 3 at height 20, and so on up to 16 at height 150. One thread mines a block in a few seconds. Stop with:

```bash
curl --digest -u rpc_daemon_user:abc123 http://127.0.0.1:18081/stop_mining -d ''
```

## Building

```bash
docker build --target monero-daemon-rpc --build-arg VARIANT=private-testnet -t monero-daemon-rpc:private-testnet .
docker build --target monero-wallet-rpc --build-arg VARIANT=private-testnet -t monero-wallet-rpc:private-testnet .
docker build --target monero-wallet-light --build-arg VARIANT=private-testnet -t monero-wallet-light:private-testnet .
```

`VARIANT` names a file in [patches](../patches), which is applied to the submodule in the build, on a copy of the sources. The submodule is not modified.

## The patch

From [haveno-dex/monero@61212af](https://github.com/haveno-dex/monero/commit/61212af8bf3a41f36bbf2f07fc7fe99dff9add4b), by woodser. It changes the testnet table in `src/hardforks/hardforks.cpp` and nothing else:

```diff
--- a/src/hardforks/hardforks.cpp
+++ b/src/hardforks/hardforks.cpp
@@ -82,24 +82,24 @@ const hardfork_t testnet_hard_forks[] = {
   { 1, 1, 0, 1341378000 },
 
   // version 2 starts from block 624634, which is on or around the 23rd of November, 2015. Fork time finalised on 2015-11-20. No fork voting occurs for the v2 fork.
-  { 2, 624634, 0, 1445355000 },
+  { 2, 10, 0, 1445355000 },
 
   // versions 3-5 were passed in rapid succession from September 18th, 2016
-  { 3, 800500, 0, 1472415034 },
-  { 4, 801219, 0, 1472415035 },
-  { 5, 802660, 0, 1472415036 + 86400*180 }, // add 5 months on testnet to shut the update warning up since there's a large gap to v6
-
-  { 6, 971400, 0, 1501709789 },
-  { 7, 1057027, 0, 1512211236 },
-  { 8, 1057058, 0, 1533211200 },
-  { 9, 1057778, 0, 1533297600 },
-  { 10, 1154318, 0, 1550153694 },
-  { 11, 1155038, 0, 1550225678 },
-  { 12, 1308737, 0, 1569582000 },
-  { 13, 1543939, 0, 1599069376 },
-  { 14, 1544659, 0, 1599069377 },
-  { 15, 1982800, 0, 1652727000 },
-  { 16, 1983520, 0, 1652813400 },
+  { 3, 20, 0, 1472415034 },
+  { 4, 30, 0, 1472415035 },
+  { 5, 40, 0, 1472415036 + 86400*180 }, // add 5 months on testnet to shut the update warning up since there's a large gap to v6
+
+  { 6, 50, 0, 1501709789 },
+  { 7, 60, 0, 1512211236 },
+  { 8, 70, 0, 1533211200 },
+  { 9, 80, 0, 1533297600 },
+  { 10, 90, 0, 1550153694 },
+  { 11, 100, 0, 1550225678 },
+  { 12, 110, 0, 1569582000 },
+  { 13, 120, 0, 1599069376 },
+  { 14, 130, 0, 1599069377 },
+  { 15, 140, 0, 1652727000 },
+  { 16, 150, 0, 1652813400 },
 };
 const size_t num_testnet_hard_forks = sizeof(testnet_hard_forks) / sizeof(testnet_hard_forks[0]);
 const uint64_t testnet_hard_fork_version_1_till = 624633;
```

## Maintenance

The patch applies to every commit of woodser/monero pinned by the monero-cpp releases so far, since that file has not changed since 2022. If monero-project adds a hardfork to the testnet table, the patch stops applying and the build fails. `bin/update_monero_rpc.sh` checks it when the submodule is updated. To regenerate it, edit the table in the submodule, give the new version a low height, and save the diff:

```bash
cd external/monero-project
$EDITOR src/hardforks/hardforks.cpp
git diff > ../../patches/private-testnet.patch
git checkout src/hardforks/hardforks.cpp
```
