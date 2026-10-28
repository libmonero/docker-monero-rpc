# Monero RPC Docker

[![Build](https://github.com/libmonero/docker-monero-rpc/actions/workflows/build.yml/badge.svg)](https://github.com/libmonero/docker-monero-rpc/actions/workflows/build.yml)
[![Test](https://github.com/libmonero/docker-monero-rpc/actions/workflows/test.yml/badge.svg)](https://github.com/libmonero/docker-monero-rpc/actions/workflows/test.yml)
[![Lint](https://github.com/libmonero/docker-monero-rpc/actions/workflows/lint.yml/badge.svg)](https://github.com/libmonero/docker-monero-rpc/actions/workflows/lint.yml)
[![Release](https://img.shields.io/github/v/release/libmonero/docker-monero-rpc?logo=github)](https://github.com/libmonero/docker-monero-rpc/releases)

[![License](https://img.shields.io/github/license/libmonero/docker-monero-rpc)](LICENSE)
[![Platforms](https://img.shields.io/badge/platforms-linux%2Famd64%20%7C%20linux%2Farm64-blue?logo=docker&logoColor=white)](#images)

> [!WARNING]
>
> Work in progress. This is currently under maintenance and unfunded, expect bugs and breaking changes.

Dockerized `monerod` and `monero-wallet-rpc` built from [woodser/monero](https://github.com/woodser/monero) source fork, for running the RPC servers used by [monero-cpp](https://github.com/woodser/monero-cpp), [monero-python](https://github.com/everoddandeven/monero-python), [monero-java](https://github.com/woodser/monero-java) and [monero-ts](https://github.com/woodser/monero-ts).

* Separate `monerod` and `monero-wallet-rpc` images built from a single Dockerfile.
* Builds for `linux/amd64` and `linux/arm64`.
* Meant for development and testing against regtest, a [private testnet](docs/private-testnet.md) with fast hardforks, or mainnet.

## Images

| Image | Variant | Binary | Default ports |
|-------|---------|--------|---------------|
| `monero-daemon-rpc` | [default](https://github.com/woodser/monero) | `monerod` | `18080` p2p, `18081` rpc |
| `monero-daemon-rpc` | [private-testnet](docs/private-testnet.md) | `monerod` | `28080` p2p, `28081` rpc |
| `monero-wallet-rpc` | [default](https://github.com/woodser/monero) | `monero-wallet-rpc` | `18083` rpc |
| `monero-wallet-rpc` | [private-testnet](docs/private-testnet.md) | `monero-wallet-rpc` | `28083` rpc |

The `private-testnet` variant is built with a [patch](patches/private-testnet.patch) that schedules the testnet hardforks at low block heights, for private testnets. Its tags are prefixed with `private-testnet-`.

## Documentation

* [Building](docs/building.md)
* [Usage](docs/usage.md)
* [Releases](docs/releases.md)
* [Security](docs/security.md)
* [Tests](docs/testing.md), with a regtest [compose file](examples/regtest/docker-compose.yml)
* [Private testnet](docs/private-testnet.md), with a [compose file](examples/private-testnet/docker-compose.yml)
* [Compose example](examples/docker-compose.yml) with a node and a wallet

## Related projects

* [monero-cpp](https://github.com/woodser/monero-cpp)
* [monero-python](https://github.com/libmonero/monero-python)
* [monero-java](https://github.com/woodser/monero-java)
* [monero-ts](https://github.com/woodser/monero-ts)
* [monero-csharp](https://github.com/libmonero/monero-csharp)

## Credits

Thanks to [@sethforprivacy](https://github.com/sethforprivacy) and [@lalanza808](https://github.com/lalanza808), this project started from their work:

* [simple-monerod-docker](https://github.com/sethforprivacy/simple-monerod-docker): the static build on Alpine, the healthcheck, the smoke tests and the build and publish workflows.
* [docker-monero-node](https://github.com/lalanza808/docker-monero-node): the images the tests of monero-python and monero-java have been using, and the compose files with log rotation and variables.

Parts of both were adapted under their MIT licenses, see [NOTICE](NOTICE). The patch of the [private testnet](docs/private-testnet.md) is by woodser, from [haveno-dex/monero](https://github.com/haveno-dex/monero).

## License

This project is licensed under MIT.

## Donations

If this project has been valuable to you, please consider donating to support its continued development. 🙏

<p align="center">
	<code>XMR</code><br>
	<img src="donate.png" style="margin-top: 5px" width="115" height="115"/><br>
	<code>85S2XbtTD6nLSt31YYLZuT1uzToXv1tGBHb2NQM6xKGKjjH3e1ZAjRGepUKYnd3Rc4HMG2ZUrQ8zzArd7dSwdyH55HxPKGD</code>
</p>
