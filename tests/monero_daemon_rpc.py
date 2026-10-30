import logging
from typing import Any

from monero_rpc_connection import MoneroRpcConnection

logger: logging.Logger = logging.getLogger("MoneroDaemonRpc")


class MoneroDaemonRpc:
    """Client of the rpc of monerod, only what the tests use."""

    def __init__(self, uri: str, username: str | None = None, password: str | None = None) -> None:
        self.rpc = MoneroRpcConnection(uri, username, password, timeout=120)

    def get_version(self) -> dict[str, Any]:
        """The `version` (major << 16 | minor), `release` and `current_height` of the rpc."""
        return self.rpc.send_json_request("get_version")

    def get_info(self) -> dict[str, Any]:
        """The state of the node: `height`, `nettype`, `testnet`, `top_block_hash`, `version`, ..."""
        return self.rpc.send_json_request("get_info")

    def get_height(self) -> int:
        return self.rpc.send_json_request("get_block_count")["count"]

    def hard_fork_info(self, version: int | None = None) -> dict[str, Any]:
        """The state of the hard fork of `version`, or of the last, with its `earliest_height`."""
        return self.rpc.send_json_request("hard_fork_info", {} if version is None else {"version": version})

    def generate_blocks(self, address: str, blocks: int) -> dict[str, Any]:
        """Make blocks, only regtest has it (`--regtest --fixed-difficulty=1` for it to be quick)."""
        return self.rpc.send_json_request("generateblocks", {"wallet_address": address, "amount_of_blocks": blocks})

    def start_mining(self, address: str, threads: int = 1) -> None:
        self.rpc.send_path_request("start_mining", {
            "miner_address": address, "threads_count": threads, "do_background_mining": False, "ignore_battery": True})

    def stop_mining(self) -> None:
        self.rpc.send_path_request("stop_mining")
