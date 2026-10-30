import logging
import re

from conftest import Stack
from monero_wallet_rpc import MoneroWalletRpc

logger: logging.Logger = logging.getLogger("TestWalletRpc")


def test_get_version(wallet: MoneroWalletRpc) -> None:
    version = wallet.get_version()
    logger.info(f"Rpc version {version['version'] >> 16}.{version['version'] & 0xffff}")
    assert version["version"] >> 16 == 1


def test_create_wallet(stack: Stack) -> None:
    account = stack.new_account("created")
    logger.info(f"Created {account.address}")
    assert stack.wallet.get_address() == account.address
    assert re.fullmatch("[0-9a-f]{64}", account.view_key)


def test_validate_address(stack: Stack, variant: str) -> None:
    account = stack.new_account("validated")
    result = stack.wallet.validate_address(account.address)
    assert result["valid"]
    assert result["nettype"] == ("testnet" if variant == "private-testnet" else "mainnet")
    assert not stack.wallet.validate_address("not an address")["valid"]
