import logging

import pytest
from conftest import BLOCKS, Account
from monero_daemon_rpc import MoneroDaemonRpc

logger: logging.Logger = logging.getLogger("TestDaemonRpc")


def test_get_version(node: MoneroDaemonRpc) -> None:
    version = node.get_version()
    logger.info(f"Rpc version {version['version'] >> 16}.{version['version'] & 0xffff}")
    assert version["version"] >> 16 == 3


def test_get_info(node: MoneroDaemonRpc, variant: str, account: Account) -> None:
    info = node.get_info()
    logger.info(f"{info['nettype']} at height {info['height']}, top block {info['top_block_hash']}")
    assert info["height"] > BLOCKS[variant]
    assert info["nettype"] == ("testnet" if variant == "private-testnet" else "fakechain")
    assert info["testnet"] == (variant == "private-testnet")
    assert info["offline"]


def test_get_height(node: MoneroDaemonRpc) -> None:
    assert node.get_height() == node.get_info()["height"]


def test_hard_fork_info(node: MoneroDaemonRpc, variant: str, account: Account) -> None:
    info = node.hard_fork_info()
    logger.info(f"Hard fork version {info['version']}, enabled {info['enabled']}")
    assert info["enabled"]
    assert info["version"] >= 16
    if variant == "private-testnet":
        # 1983520 in the default images, see docs/private-testnet.md
        assert node.hard_fork_info(16)["earliest_height"] == 150


def test_generate_blocks(node: MoneroDaemonRpc, variant: str, account: Account) -> None:
    if variant != "default":
        pytest.skip("generateblocks only exists in regtest")
    height = node.get_height()
    assert node.generate_blocks(account.address, 2)["height"] == height + 1
    assert node.get_height() == height + 2
