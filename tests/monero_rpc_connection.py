import logging
from typing import Any

import requests
from requests.auth import HTTPDigestAuth

logger: logging.Logger = logging.getLogger("MoneroRpcConnection")


def redact(value: Any) -> Any:
    """A request without the view keys and the passwords, the logs are published."""
    if isinstance(value, dict):
        return {key: "***" if key in ("view_key", "password") else redact(item) for key, item in value.items()}
    if isinstance(value, list):
        return [redact(item) for item in value]
    return value


class MoneroRpcError(RuntimeError):
    """Error answered by a server, a http status or the error of a json rpc."""

    def __init__(self, status: int, body: str) -> None:
        super().__init__(f"{status}: {body}")
        self.status = status
        self.body = body


class MoneroRpcConnection:
    """Json over http to a monero server, the part of the connection of monero-python that the clients use.

    The daemon and the wallet answer to json rpc and to paths, monero-lws only to paths.
    """

    def __init__(self, uri: str, username: str | None = None, password: str | None = None, timeout: float = 60.0) -> None:
        self.uri = uri.rstrip("/")
        self.timeout = timeout
        self.session = requests.Session()
        if username is not None:
            self.session.auth = HTTPDigestAuth(username, password or "")

    def send_path_request(self, path: str, body: dict[str, Any] | None = None) -> Any:
        """Post a json body to a path and return the parsed json response.

        :raises MoneroRpcError: on a status other than 200.
        """
        response = self.session.post(f"{self.uri}/{path}", json=body or {}, timeout=self.timeout)
        logger.debug(f"{response.status_code} /{path} {response.text[:500]}")
        if not response.ok:
            raise MoneroRpcError(response.status_code, response.text)
        return response.json()

    def send_json_request(self, method: str, params: dict[str, Any] | None = None) -> Any:
        """Call a method of /json_rpc and return its result.

        :raises MoneroRpcError: on a status other than 200 or an error in the answer.
        """
        body = {"jsonrpc": "2.0", "id": "0", "method": method, "params": params or {}}
        logger.debug(f"POST /json_rpc {redact(body)}")
        answer = self.send_path_request("json_rpc", body)
        if "error" in answer:
            raise MoneroRpcError(answer["error"].get("code", 0), answer["error"].get("message", ""))
        return answer["result"]
