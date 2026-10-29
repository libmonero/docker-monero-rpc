import logging
import time

import zmq

logger: logging.Logger = logging.getLogger("zmq")


class Subscriber:
    """Listens to a zmq pub socket for a topic, messages sent before it is created are lost."""

    def __init__(self, endpoint: str, topic: str) -> None:
        self.socket = zmq.Context().socket(zmq.SUB)
        self.socket.setsockopt_string(zmq.SUBSCRIBE, topic)
        self.socket.connect(endpoint)
        logger.debug(f"Subscribed to {topic} at {endpoint}")
        # the subscription takes a moment to reach the publisher
        time.sleep(1)

    def receive(self, timeout: float = 60.0) -> str:
        if self.socket.poll(int(timeout * 1000)) == 0:
            raise TimeoutError(f"no message in {timeout:g} seconds")
        message = self.socket.recv().decode(errors="replace")
        logger.debug(f"Received {message[:300]}")
        return message

    def close(self) -> None:
        self.socket.close()

    def __enter__(self) -> "Subscriber":
        return self

    def __exit__(self, *args: object) -> None:
        self.close()
