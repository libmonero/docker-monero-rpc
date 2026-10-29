import logging

from conftest import Account, Stack
from monero_daemon_light import MoneroDaemonLight
from zmq_utils import Subscriber

logger: logging.Logger = logging.getLogger("TestZmq")


def test_node_publishes_blocks(stack: Stack, account: Account) -> None:
    with Subscriber(stack.node_zmq, "json-minimal-chain_main") as blocks:
        stack.mine(1, account.address)
        message = blocks.receive()
        logger.info(f"The node published {message[:80]}")
        assert message.startswith("json-minimal-chain_main:")


def test_light_publishes_payments(light: MoneroDaemonLight, stack: Stack, account: Account) -> None:
    webhook = light.webhook_add_tx_confirmation("zmq", account.address, token="test", confirmations=1)
    try:
        with Subscriber(stack.light_zmq, "json-full-payment_hook") as payments:
            stack.mine(1, account.address)
            message = payments.receive()
            logger.info(f"Light published a payment: {message[:120]}")
            assert "tx-confirmation" in message
    finally:
        light.webhook_delete_uuid([webhook["event_id"]])
