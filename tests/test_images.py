"""The images alone: what they report, who runs them, and the three ways to configure and run them.

A daemon and a wallet are started on stagenet, offline. The light wallet server follows a regtest node.
"""
import logging
import pathlib
import re
import subprocess

import pytest
import requests
from conftest import LOG_LEVEL
from container import Containers, client
from monero_daemon_light import MoneroDaemonLight
from monero_daemon_rpc import MoneroDaemonRpc
from monero_rpc_connection import MoneroRpcError
from monero_wallet_rpc import MoneroWalletRpc

logger: logging.Logger = logging.getLogger("TestImages")

ROOT = pathlib.Path(__file__).resolve().parent.parent

# the heights of the hard fork versions 2 and 16 of the testnet
HARD_FORKS = {"default": (624634, 1983520), "private-testnet": (10, 150)}

MODES = ["args", "config", "hardened"]


@pytest.fixture(scope="session")
def monero_version() -> str:
    """The version monero-project reports for the submodule commit."""
    return subprocess.run([ROOT / "bin" / "monero_version.sh"], capture_output=True, text=True, check=True).stdout.strip()


@pytest.fixture(scope="session")
def lws_version() -> str:
    text = (ROOT / "external" / "monero-lws" / "src" / "lws_version.h.in").read_text()
    return re.search(r'id\[\] = "(.*)";', text).group(1)  # type: ignore[union-attr]


def image(request: pytest.FixtureRequest, name: str) -> str:
    value = request.config.getoption(f"--{name}-image")
    if not value:
        pytest.skip(f"set --{name}-image")
    return value


@pytest.fixture
def daemon_image(request: pytest.FixtureRequest) -> str:
    return image(request, "daemon")


@pytest.fixture
def wallet_image(request: pytest.FixtureRequest) -> str:
    return image(request, "wallet")


@pytest.fixture
def light_image(request: pytest.FixtureRequest) -> str:
    return image(request, "light")


@pytest.fixture(params=["daemon", "wallet", "light"])
def any_image(request: pytest.FixtureRequest) -> tuple[str, str]:
    """An image and the part of its name that tells its kind."""
    return request.param, image(request, request.param)


def options(mode: str, args: list[str], config_path: str) -> dict:
    """How the same options are given: as arguments, in a config file, or in a config file of a hardened container."""
    if mode == "args":
        return {"args": args}
    # a flag is name=1 in a config file
    config = "".join(f"{arg.removeprefix('--')}{'' if '=' in arg else '=1'}\n" for arg in args)
    return {"args": [f"--config-file={config_path}"], "config": config, "config_path": config_path, "hardened": mode == "hardened"}


def test_version(any_image: tuple[str, str], monero_version: str, lws_version: str) -> None:
    kind, name = any_image
    output = client.containers.run(name, ["--version"], remove=True).decode()
    logger.info(output)
    assert (f"monero-lws version {lws_version}" if kind == "light" else f"({monero_version})") in output


def test_runs_as_a_user(any_image: tuple[str, str]) -> None:
    assert client.containers.run(any_image[1], ["-u"], entrypoint="id", remove=True).decode().strip() != "0"


def test_variant_label(any_image: tuple[str, str], variant: str) -> None:
    assert client.images.get(any_image[1]).labels["io.libmonero.variant"] == variant


@pytest.mark.parametrize("mode", MODES)
def test_daemon(containers: Containers, daemon_image: str, mode: str) -> None:
    args = ["--stagenet", "--offline", "--rpc-bind-ip=0.0.0.0", "--confirm-external-bind", "--rpc-bind-port=40001",
            "--rpc-login=user:pass", f"--log-level={LOG_LEVEL}"]
    container = containers.run(daemon_image, ports=[40001], **options(mode, args, "/home/monero/.bitmonero/bitmonero.conf"))
    container.wait_healthy()
    info = MoneroDaemonRpc(container.url(40001), "user", "pass").get_info()
    assert info["nettype"] == "stagenet"
    assert container.stop() == 0


def test_daemon_hard_forks(containers: Containers, daemon_image: str, variant: str) -> None:
    container = containers.run(daemon_image, ["--testnet", "--offline", "--rpc-bind-ip=0.0.0.0", "--confirm-external-bind",
                                              f"--log-level={LOG_LEVEL}"], ports=[28081])
    container.wait_healthy()
    node = MoneroDaemonRpc(container.url(28081))
    assert (node.hard_fork_info(2)["earliest_height"], node.hard_fork_info(16)["earliest_height"]) == HARD_FORKS[variant]


@pytest.mark.parametrize("mode", MODES)
def test_wallet(containers: Containers, wallet_image: str, mode: str) -> None:
    args = ["--stagenet", "--rpc-bind-ip=0.0.0.0", "--confirm-external-bind", "--rpc-bind-port=40001", "--rpc-login=user:pass",
            "--wallet-dir=/home/monero/wallets", "--log-file=/dev/null", f"--log-level={LOG_LEVEL}"]
    container = containers.run(wallet_image, ports=[40001], **options(mode, args, "/home/monero/wallets/wallet.conf"))
    container.wait_healthy()
    wallet = MoneroWalletRpc(container.url(40001), "user", "pass")
    if mode == "args":
        wallet.create_wallet("smoke", "pass")
        assert container.exec("test", "-f", "/home/monero/wallets/smoke.keys")[0] == 0
    assert container.stop() == 0


def test_wallet_survives_openalias(containers: Containers, wallet_image: str) -> None:
    """The lookup can be slow or fail where there is no dnssec, the wallet only has to survive it."""
    args = ["--stagenet", "--rpc-bind-ip=0.0.0.0", "--confirm-external-bind", "--rpc-bind-port=40001", "--rpc-login=user:pass",
            "--wallet-dir=/home/monero/wallets", "--log-file=/dev/null", f"--log-level={LOG_LEVEL}"]
    container = containers.run(wallet_image, args, ports=[40001])
    container.wait_healthy()
    wallet = MoneroWalletRpc(container.url(40001), "user", "pass")
    wallet.rpc.timeout = 10
    try:
        wallet.validate_address("donate@getmonero.org", any_net_type=True, allow_openalias=True)
    except (MoneroRpcError, requests.RequestException) as e:
        logger.info(f"The lookup failed: {e!r}")
    assert container.status().startswith("running")


@pytest.mark.parametrize("mode", MODES)
def test_light(containers: Containers, daemon_image: str, light_image: str, mode: str) -> None:
    """lws exits when it cannot connect to a node, so a regtest one is started for it."""
    network = containers.network()
    node = containers.run(daemon_image, ["--regtest", "--offline", "--no-igd", "--rpc-bind-ip=0.0.0.0", "--rpc-bind-port=18081",
                                         "--confirm-external-bind", "--zmq-rpc-bind-ip=0.0.0.0", "--zmq-rpc-bind-port=18082",
                                         "--confirm-zmq-rpc-external-bind", "--zmq-pub=tcp://0.0.0.0:18083",
                                         f"--log-level={LOG_LEVEL}"], network=network)
    node.wait_healthy()
    port = 8443 if mode == "args" else 8444
    args = [f"--daemon=tcp://{node.name}:18082", f"--sub=tcp://{node.name}:18083", "--regtest",
            f"--rest-server=http://0.0.0.0:{port}", "--confirm-external-bind", f"--log-level={LOG_LEVEL}"]
    light = containers.run(light_image, ports=[port], network=network, **options(mode, args, "/home/monero/.bitmonero/lws.conf"))
    light.wait_healthy()
    assert MoneroDaemonLight(uri=light.url(port)).get_version()["server_type"]
    if mode == "args":
        assert light.exec("monero-lws-admin", "--help")[0] == 0
    assert light.stop() == 0
