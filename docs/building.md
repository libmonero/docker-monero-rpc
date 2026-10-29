# Building

1. Install [Docker](https://docs.docker.com/engine/install/) with [Buildx](https://docs.docker.com/build/concepts/overview/#buildx).
2. Clone the repository and initialize its submodules with `./bin/update_submodules.sh`. `git clone --recurse-submodules` also clones a copy of Monero inside monero-lws, which is not used.
3. Build the images:
    ```bash
    docker build --target monero-daemon-rpc -t monero-daemon-rpc .
    docker build --target monero-wallet-rpc -t monero-wallet-rpc .
    docker build --target monero-wallet-light -t monero-wallet-light .
    ```
    Or `make build`, see `make help`.
4. Run the tests: `./bin/smoke_test.sh <image name> <image>` for each image, or `make test`.

The Monero version of the images is the one of the submodule, `./bin/monero_version.sh` prints it as `monerod --version` does.

`monero-wallet-light` is [monero-lws](https://github.com/vtnerd/monero-lws) at the tag of the `external/monero-lws` submodule, built against the same monero-project. Use the release branch of monero-lws that matches the Monero of the submodule, `release-v1.0_0.18` for Monero 0.18: `git -C external/monero-lws fetch --tags && git -C external/monero-lws checkout v1.0.5`, and commit the new reference.

## Variants

`VARIANT` names the patches in [patches](../patches) to apply to the sources, see [private testnet](private-testnet.md):

```bash
docker build --target monero-daemon-rpc --build-arg VARIANT=private-testnet -t monero-daemon-rpc:private-testnet .
```

## Limiting the build

The build uses all the cores. Each compiler job can take more than 1 GB of memory, on a machine with little of it limit the jobs with `--build-arg NPROC=1`, or `make build NPROC=1`.

## Cache

The compiler cache is kept in a Docker cache mount, so after a change in the submodule only the files that changed are compiled again. Docker removes cache mounts that have not been used for a while, then the next build compiles everything.

## Updating monero-project

`./bin/update_monero_rpc.sh <tag>` moves the submodule to the commit pinned by a [monero-cpp](https://github.com/woodser/monero-cpp) release, for example `./bin/update_monero_rpc.sh v0.9.10`, and checks that the patches still apply. Commit the new submodule reference.

## Without Docker

`./bin/build_monero_rpc.sh` builds `monerod` and `monero-wallet-rpc` from the submodule into `external/monero-project/build/release/bin`. The dependencies have to be installed, `./bin/install_dependencies.sh` does it on Alpine.
