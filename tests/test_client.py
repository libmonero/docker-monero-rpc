import logging

from conftest import Account, Stack
from monero_daemon_light import MoneroDaemonLight

logger: logging.Logger = logging.getLogger("TestClient")


def test_get_version(light: MoneroDaemonLight, variant: str) -> None:
    version = light.get_version()
    logger.info(f"Server {version['server_type']} {version['server_version']}, network testnet={version['testnet']}")
    assert version["server_type"]
    assert version["max_subaddresses"] == 1000
    assert version["testnet"] == (variant == "private-testnet")


def test_daemon_status(light: MoneroDaemonLight) -> None:
    status = light.daemon_status()
    logger.info(f"Daemon status {status}")
    assert "state" in status
    assert status["height"] > 0


def test_login_existing_account(light: MoneroDaemonLight, account: Account) -> None:
    result = light.login(account.address, account.view_key)
    assert result["new_address"] is False


def test_get_address_info(light: MoneroDaemonLight, stack: Stack, account: Account) -> None:
    info = light.get_address_info(account.address, account.view_key)
    logger.info(f"Scanned {info['scanned_height']} of {info['blockchain_height']}, node at {stack.node_height()}")
    assert info["scanned_height"] >= stack.node_height() - 1
    assert info["blockchain_height"] >= info["scanned_height"]


def test_get_address_txs(light: MoneroDaemonLight, account: Account) -> None:
    result = light.get_address_txs(account.address, account.view_key)
    logger.info(f"Received {result['total_received']} in {len(result['transactions'])} transaction(s)")
    assert int(result["total_received"]) > 0, (result, light.list_accounts())
    assert result["transactions"]


def test_get_subaddrs(light: MoneroDaemonLight, account: Account) -> None:
    light.provision_subaddrs(account.address, account.view_key, maj_i=0, min_i=1, n_maj=1, n_min=2)
    result = light.get_subaddrs(account.address, account.view_key)
    assert result["all_subaddrs"]


def test_provision_subaddrs(light: MoneroDaemonLight, account: Account) -> None:
    result = light.provision_subaddrs(account.address, account.view_key, maj_i=0, min_i=1, n_maj=1, n_min=2)
    # the range may have been provisioned already, then there is nothing new
    assert result["all_subaddrs"]


def test_get_unspent_outs(light: MoneroDaemonLight, account: Account) -> None:
    # the coinbase outputs have no ring, a higher mixin leaves them out
    result = light.get_unspent_outs(account.address, account.view_key, amount=0, mixin=0, use_dust=True)
    logger.info(f"{len(result.get('outputs', []))} unspent output(s), amount {result['amount']}, fee {result['per_byte_fee']} per byte")
    assert result["per_byte_fee"] > 0
    assert int(result["amount"]) > 0
    assert result["outputs"]
