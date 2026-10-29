from conftest import Account, Stack
from monero_daemon_light import MoneroDaemonLight


def test_get_version(light: MoneroDaemonLight, variant: str) -> None:
    version = light.get_version()
    assert version["server_type"]
    assert version["max_subaddresses"] == 1000
    assert version["testnet"] == (variant == "private-testnet")


def test_daemon_status(light: MoneroDaemonLight) -> None:
    status = light.daemon_status()
    assert "state" in status
    assert status["height"] > 0


def test_login_existing_account(light: MoneroDaemonLight, account: Account) -> None:
    result = light.login(account.address, account.view_key)
    assert result["new_address"] is False


def test_get_address_info(light: MoneroDaemonLight, stack: Stack, account: Account) -> None:
    info = light.get_address_info(account.address, account.view_key)
    assert info["scanned_height"] >= stack.node_height() - 1
    assert info["blockchain_height"] >= info["scanned_height"]


def test_get_address_txs(light: MoneroDaemonLight, account: Account) -> None:
    result = light.get_address_txs(account.address, account.view_key)
    assert int(result["total_received"]) > 0, (result, light.list_accounts())
    assert result["transactions"]


def test_get_subaddrs(light: MoneroDaemonLight, account: Account) -> None:
    light.provision_subaddrs(account.address, account.view_key, maj_i=0, min_i=1, n_maj=1, n_min=2)
    result = light.get_subaddrs(account.address, account.view_key)
    assert result["all_subaddrs"]


def test_provision_subaddrs(light: MoneroDaemonLight, account: Account) -> None:
    result = light.provision_subaddrs(account.address, account.view_key, maj_i=0, min_i=1, n_maj=1, n_min=2)
    assert "new_subaddrs" in result
    assert "all_subaddrs" in result


def test_get_unspent_outs(light: MoneroDaemonLight, account: Account) -> None:
    result = light.get_unspent_outs(account.address, account.view_key, amount=0, mixin=15, use_dust=True)
    assert "per_byte_fee" in result
    assert "outputs" in result
