import logging
import os
import pathlib
import subprocess
import time
import uuid
from typing import NamedTuple

import pytest

from monero_daemon_light import MoneroDaemonLight
from monero_daemon_rpc import MoneroDaemonRpc
from monero_wallet_rpc import MoneroWalletRpc

logger: logging.Logger = logging.getLogger("conftest")

# blocks made before the tests, the last hardfork of the private testnet is at height 150
BLOCKS = {"default": 20, "private-testnet": 160}

# debug, the highest (4) when the job is rerun with the debug logging of github
LOG_LEVEL = 4 if os.environ.get("RUNNER_DEBUG") == "1" else 2


def pytest_configure(config: pytest.Config) -> None:
    # one line per request is not needed from the libraries
    logging.getLogger("urllib3").setLevel(logging.WARNING)


def pytest_addoption(parser: pytest.Parser) -> None:
    parser.addoption("--variant", default="default", choices=list(BLOCKS), help="variant of the images")
    parser.addoption("--daemon-image", default=os.environ.get("MONERO_DAEMON_IMAGE"), help="monero-daemon-rpc image")
    parser.addoption("--wallet-image", default=os.environ.get("MONERO_WALLET_IMAGE"), help="monero-wallet-rpc image")
    parser.addoption("--logs-dir", default=None, help="directory to save the logs of the containers to")
    parser.addoption("--light-image", default=os.environ.get("MONERO_LIGHT_IMAGE"), help="monero-wallet-light image")


def docker(*args: str, check: bool = True) -> str:
    return subprocess.run(["docker", *args], capture_output=True, text=True, check=check).stdout.strip()


class Account(NamedTuple):
    address: str
    view_key: str


class Stack:
    """A node, a wallet and a light wallet server on a docker network of their own.

    Regtest is used by the default variant and the testnet by private-testnet, the ports
    that tests talk to are published to localhost on free ports."""

    def __init__(self, variant: str, daemon_image: str, wallet_image: str, light_image: str) -> None:
        self.variant = variant
        self.images = {"node": daemon_image, "wallet": wallet_image, "light": light_image}
        self.network = f"light-tests-{uuid.uuid4().hex[:8]}"
        self.node: MoneroDaemonRpc
        self.wallet: MoneroWalletRpc
        self.light: MoneroDaemonLight
        self.net_args = {
            "default": {"node": ["--regtest", "--fixed-difficulty=1"], "wallet": [], "light": ["--regtest"]},
            "private-testnet": {"node": ["--testnet", "--fixed-difficulty=1"], "wallet": ["--testnet"], "light": ["--network=test"]},
        }[variant]

    def name(self, service: str) -> str:
        return f"{self.network}-{service}"

    def run(self, service: str, args: list[str], ports: list[int]) -> None:
        publish = [arg for port in ports for arg in ("--publish", f"127.0.0.1::{port}")]
        logger.info(f"Starting {service} from {self.images[service]}: {' '.join(args)}")
        docker("run", "-d", "--name", self.name(service), "--network", self.network, "--health-interval=5s",
               "--health-start-period=5s", *publish, self.images[service], *args)

    def wait_healthy(self, service: str, timeout: float = 120.0) -> None:
        deadline = time.monotonic() + timeout
        while time.monotonic() < deadline:
            if docker("inspect", "-f", "{{.State.Health.Status}}", self.name(service)) == "healthy":
                logger.info(f"{service} is healthy")
                return
            time.sleep(2)
        raise RuntimeError(f"{service} did not become healthy\n{self.logs(service)}")

    def logs(self, service: str, tail: int = 30) -> str:
        # the daemons log to stderr
        result = subprocess.run(["docker", "logs", "--tail", str(tail), self.name(service)], capture_output=True, text=True, check=False)
        return (result.stdout + result.stderr).strip()

    def save_logs(self, directory: pathlib.Path) -> None:
        """Save the whole log of every container, the daemons log to stderr."""
        directory.mkdir(parents=True, exist_ok=True)
        for service in self.images:
            result = subprocess.run(["docker", "logs", self.name(service)], capture_output=True, text=True, check=False)
            (directory / f"{service}.log").write_text(result.stdout + result.stderr)
            logger.info(f"Saved the log of {service} to {directory / f'{service}.log'}")

    def summary(self, service: str) -> str:
        """The state of a container and its distinct log lines with their count, loops would fill the tail."""
        state = docker("inspect", "-f", "{{.State.Status}} exit code {{.State.ExitCode}}", self.name(service), check=False)
        result = subprocess.run(["docker", "logs", self.name(service)], capture_output=True, text=True, check=False)
        counts: dict[str, int] = {}
        for line in (result.stdout + result.stderr).splitlines():
            counts[line[24:]] = counts.get(line[24:], 0) + 1
        return f"{service}: {state}\n" + "\n".join(f"{count}x {line}" if count > 1 else line for line, count in counts.items())

    def url(self, service: str, port: int) -> str:
        return docker("port", self.name(service), f"{port}/tcp").splitlines()[0]

    def start_node(self) -> None:
        self.run("node", [*self.net_args["node"], "--offline", "--no-igd", "--rpc-bind-ip=0.0.0.0", "--rpc-bind-port=18081",
                          "--confirm-external-bind", "--zmq-rpc-bind-ip=0.0.0.0", "--zmq-rpc-bind-port=18082",
                          "--confirm-zmq-rpc-external-bind", "--zmq-pub=tcp://0.0.0.0:18083", f"--log-level={LOG_LEVEL}"], [18081, 18083])
        self.wait_healthy("node")
        self.node = MoneroDaemonRpc(f"http://{self.url('node', 18081)}")
        self.node_zmq = f"tcp://{self.url('node', 18083)}"

    def start_wallet(self) -> None:
        self.run("wallet", [*self.net_args["wallet"], "--offline", "--rpc-bind-ip=0.0.0.0", "--rpc-bind-port=18084",
                            "--confirm-external-bind", "--disable-rpc-login", "--wallet-dir=/home/monero/wallets",
                            "--log-file=/dev/null", f"--log-level={LOG_LEVEL}"], [18084])
        self.wait_healthy("wallet")
        self.wallet = MoneroWalletRpc(f"http://{self.url('wallet', 18084)}")

    def start_light(self) -> None:
        self.run("light", [*self.net_args["light"], f"--daemon=tcp://{self.name('node')}:18082",
                           f"--sub=tcp://{self.name('node')}:18083", "--zmq-pub=tcp://0.0.0.0:18090",
                           "--rest-server=http://0.0.0.0:8443", "--admin-rest-server=http://0.0.0.0:8444",
                           "--disable-admin-auth", "--confirm-external-bind", "--auto-accept-creation",
                           "--max-subaddresses=1000", f"--log-level={LOG_LEVEL}"], [8443, 8444, 18090])
        self.wait_healthy("light")
        self.light = MoneroDaemonLight(uri=f"http://{self.url('light', 8443)}", admin_uri=f"http://{self.url('light', 8444)}")
        self.light_zmq = f"tcp://{self.url('light', 18090)}"

    def wait_synced(self, timeout: float = 60.0) -> None:
        """Wait for the first sync of the light wallet server, which needs an account and a node with blocks.

        Its database starts at the last checkpoint of mainnet and is rolled back to the node then.
        """
        deadline = time.monotonic() + timeout
        while time.monotonic() < deadline:
            tip = self.light.get_version()["blockchain_height"]
            if tip <= self.node.get_height():
                logger.info(f"light is synced with the node, its database is at {tip}")
                return
            logger.debug(f"light database is at {tip}, the node at {self.node.get_height()}")
            time.sleep(1)
        raise RuntimeError(f"light did not sync with the node\n{self.logs('light')}")

    def start(self) -> None:
        logger.info(f"Starting the stack {self.network} for the {self.variant} variant")
        docker("network", "create", self.network)
        self.start_node()
        self.start_wallet()
        self.start_light()

    def stop(self) -> None:
        for service in self.images:
            docker("rm", "-fv", self.name(service), check=False)
        docker("network", "rm", self.network, check=False)

    def new_account(self, name: str) -> Account:
        """Create a wallet and return its keys."""
        self.wallet.create_wallet(name)
        return Account(self.wallet.get_address(), self.wallet.query_key("view_key"))

    def mine(self, blocks: int, address: str) -> int:
        """Make blocks for an address and return the height of the node."""
        target = self.node.get_height() + blocks
        logger.info(f"Making {blocks} blocks for {address[:12]}... up to height {target}")
        if self.variant == "default":
            self.node.generate_blocks(address, blocks)
        else:
            self.node.start_mining(address)
            deadline = time.monotonic() + 120
            while self.node.get_height() < target and time.monotonic() < deadline:
                time.sleep(1)
            self.node.stop_mining()
        return self.node.get_height()


@pytest.fixture(scope="session")
def variant(request: pytest.FixtureRequest) -> str:
    return request.config.getoption("--variant")


@pytest.fixture(scope="session")
def stack(request: pytest.FixtureRequest, variant: str):
    images = [request.config.getoption(f"--{name}-image") for name in ("daemon", "wallet", "light")]
    if not all(images):
        pytest.fail("the images are needed: --daemon-image, --wallet-image and --light-image")
    stack = Stack(variant, *images)
    try:
        stack.start()
        yield stack
    finally:
        logs_dir = request.config.getoption("--logs-dir")
        if logs_dir:
            stack.save_logs(pathlib.Path(logs_dir))
        stack.stop()


@pytest.fixture(scope="session")
def node(stack: Stack) -> MoneroDaemonRpc:
    return stack.node


@pytest.fixture(scope="session")
def wallet(stack: Stack) -> MoneroWalletRpc:
    return stack.wallet


@pytest.fixture(scope="session")
def light(stack: Stack) -> MoneroDaemonLight:
    return stack.light


@pytest.fixture(scope="session")
def account(stack: Stack, variant: str) -> Account:
    """An account of the light wallet server that has been mined to and scanned."""
    account = stack.new_account("miner")
    logger.info(f"Created the account {account.address[:12]}... of the miner")
    try:
        stack.light.login(account.address, account.view_key, create_account=True, generated_locally=True)
        height = stack.mine(BLOCKS[variant], account.address)
        # the account starts at the checkpoint of lws until it syncs with a node that has blocks, then it is rolled back
        stack.wait_synced()
        scanned = stack.light.wait_for_scan_height(account.address, account.view_key, height - 1, timeout_seconds=120)
        logger.info(f"The miner is scanned up to {scanned} of {height}")
    except Exception as e:
        pytest.fail(f"{e!r}\n{stack.summary('light')}\n{stack.summary('node')}", pytrace=False)
    return account
