# Monero RPC Docker

> [!NOTE]
> Work in progress.

Dockerized `monerod` and `monero-wallet-rpc` built from [woodser/monero](https://github.com/monero-project/monero) source fork, for running the RPC servers used by [monero-cpp](https://github.com/woodser/monero-cpp), [monero-python](https://github.com/everoddandeven/monero-python), [monero-java](https://github.com/woodser/monero-java) and [monero-ts](https://github.com/woodser/monero-ts).

* Separate `monerod` and `monero-wallet-rpc` images built from a single Dockerfile.
* Builds for `linux/amd64` and `linux/arm64`.
* Meant for development and testing against regtest, testnet with custom hardfork checkpoints, or mainnet.

## Images

| Image | Binary | Default ports |
|-------|--------|---------------|
| `monero-daemon-rpc` | `monerod` | `18080` p2p, `18081` rpc |
| `monero-wallet-rpc` | `monero-wallet-rpc` | `18083` rpc |

## Related projects

* [monero-cpp](https://github.com/woodser/monero-cpp)
* [monero-python](https://github.com/libmonero/monero-python)
* [monero-java](https://github.com/woodser/monero-java)
* [monero-ts](https://github.com/woodser/monero-ts)
* [monero-csharp](https://github.com/libmonero/monero-csharp)

## License

This project is licensed under MIT.

## Donations

If this project has been valuable to you, please consider donating to support its continued development.

<p align="center">
	<code>XMR</code><br>
	<img src="donate.png" style="margin-top: 5px" width="115" height="115"/><br>
	<code>85S2XbtTD6nLSt31YYLZuT1uzToXv1tGBHb2NQM6xKGKjjH3e1ZAjRGepUKYnd3Rc4HMG2ZUrQ8zzArd7dSwdyH55HxPKGD</code>
</p>
