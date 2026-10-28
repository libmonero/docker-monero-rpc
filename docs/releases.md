# Releases

The images are published to `ghcr.io/libmonero/monero-daemon-rpc` and `ghcr.io/libmonero/monero-wallet-rpc`.

## Tags

A release is a git tag `vX.Y.Z.W-N`: `X.Y.Z.W` is the Monero version of the submodule and `N` the release of this project for it, starting at 1. A change in the images without a new Monero is a new `N`, so the number is never left out.

| Tag | Moves |
|-----|-------|
| `v0.18.5.1-1` | never |
| `v0.18.5.1` | to the highest release of that Monero version |
| `latest` | to the highest release |
| `master` | with every push to `main`, tested but not released |

The [private testnet](private-testnet.md) variant has the same tags with a `private-testnet-` prefix, and `private-testnet` instead of `latest`.

Use a full tag, `v0.18.5.1-1`, when the tests need the same Monero every time.

## Releasing

```bash
./bin/update_monero_rpc.sh v0.9.10   # only for a new Monero
./bin/next_tag.sh                    # v0.18.5.1-2
git tag v0.18.5.1-2
git push <libmonero remote> v0.18.5.1-2
```

The [Release](../.github/workflows/release.yml) workflow checks that the tag matches the submodule, waits for the [Test](../.github/workflows/test.yml) run of the commit, builds both variants for `linux/amd64` and `linux/arm64`, tests the pushed images, scans them with Trivy, signs them and drafts a GitHub release with the binaries. Publish the draft when it looks right.

Protect the `v*` tags with a ruleset, a published tag should not be moved.

## Verifying

The images are signed with cosign, keyless:

```bash
cosign verify ghcr.io/libmonero/monero-daemon-rpc:v0.18.5.1-1 \
  --certificate-identity-regexp '^https://github.com/libmonero/docker-monero-rpc/\.github/workflows/release\.yml@' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

The archives of the release have a `SHA256SUMS` file.

## First release

Packages of the organization are private at first, make each one public from its settings page. The workflows need the permission to write packages in Settings, Actions, General, Workflow permissions.
