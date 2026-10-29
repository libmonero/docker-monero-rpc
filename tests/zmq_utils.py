import time

import zmq


class Subscriber:
    """Listens to a zmq pub socket for a topic, messages sent before it is created are lost."""

    def __init__(self, endpoint: str, topic: str) -> None:
        self.socket = zmq.Context().socket(zmq.SUB)
        self.socket.setsockopt_string(zmq.SUBSCRIBE, topic)
        self.socket.connect(endpoint)
        # the subscription takes a moment to reach the publisher
        time.sleep(1)

    def receive(self, timeout: float = 60.0) -> str:
        if self.socket.poll(int(timeout * 1000)) == 0:
            raise TimeoutError(f"no message in {timeout:g} seconds")
        return self.socket.recv().decode(errors="replace")

    def close(self) -> None:
        self.socket.close()

    def __enter__(self) -> "Subscriber":
        return self

    def __exit__(self, *args: object) -> None:
        self.close()
