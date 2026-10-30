import logging
from typing import Any

from monero_rpc_connection import MoneroRpcConnection

logger: logging.Logger = logging.getLogger("MoneroWalletRpc")


class MoneroWalletRpc:
    """Client of the rpc of monero-wallet-rpc, only what the tests use."""

    def __init__(self, uri: str, username: str | None = None, password: str | None = None) -> None:
        self.rpc = MoneroRpcConnection(uri, username, password, timeout=120)

    def get_version(self) -> dict[str, Any]:
        """The `version` (major << 16 | minor) of the rpc."""
        return self.rpc.send_json_request("get_version")

    def create_wallet(self, filename: str, password: str = "", language: str = "English") -> None:
        self.rpc.send_json_request("create_wallet", {"filename": filename, "password": password, "language": language})

    def get_address(self) -> str:
        """The primary address of the open wallet."""
        return self.rpc.send_json_request("get_address")["address"]

    def query_key(self, key_type: str) -> str:
        """A key of the open wallet, `view_key`, `spend_key` or `mnemonic`."""
        return self.rpc.send_json_request("query_key", {"key_type": key_type})["key"]

    def validate_address(self, address: str, any_net_type: bool = False, allow_openalias: bool = False) -> dict[str, Any]:
        """If an address is valid and of which `nettype`, an openalias address is looked up if allowed."""
        return self.rpc.send_json_request("validate_address", {
            "address": address, "any_net_type": any_net_type, "allow_openalias": allow_openalias})
