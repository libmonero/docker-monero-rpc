import json

from conftest import Account, Stack
from monero_daemon_light import MoneroDaemonLight


def addresses(accounts: list[dict]) -> list[str]:
    return [account["address"] for account in accounts]


def test_list_accounts(light: MoneroDaemonLight, account: Account) -> None:
    assert account.address in addresses(light.list_accounts()["active"])


def test_list_requests(light: MoneroDaemonLight) -> None:
    requests = light.list_requests()
    assert "create" in requests
    assert "import" in requests


def test_add_account_and_rescan(light: MoneroDaemonLight, stack: Stack) -> None:
    second = stack.new_account("second")
    assert light.add_account(second.address, second.view_key) == [second.address]
    assert second.address in addresses(light.list_accounts()["active"])
    assert light.rescan(0, [second.address]) == [second.address]


def test_modify_account_status(light: MoneroDaemonLight, stack: Stack) -> None:
    third = stack.new_account("third")
    light.add_account(third.address, third.view_key)
    assert light.modify_account_status("inactive", [third.address]) == [third.address]
    assert third.address in addresses(light.list_accounts()["inactive"])


def test_webhooks(light: MoneroDaemonLight, account: Account) -> None:
    webhook = light.webhook_add_tx_confirmation("zmq", account.address, token="test", confirmations=1)
    event_id = webhook["event_id"]
    assert event_id in json.dumps(light.webhook_list())
    light.webhook_delete_uuid([event_id])
    assert event_id not in json.dumps(light.webhook_list())
