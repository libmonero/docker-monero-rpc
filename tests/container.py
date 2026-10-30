import io
import logging
import pathlib
import tarfile
import time
import uuid
from typing import Any

import docker
from docker.models.containers import Container as DockerContainer

logger: logging.Logger = logging.getLogger("Container")

client = docker.from_env()

SECOND = 1_000_000_000


class Container:
    """A container of an image, with the ports published to localhost on free ports.

    A config file is copied into the container before it starts, as a file of a volume would be.
    """

    def __init__(self, image: str, args: list[str], name: str, ports: list[int] | None = None, network: str | None = None,
                 hardened: bool = False, config: str | None = None, config_path: str | None = None) -> None:
        self.image = image
        self.name = name
        logger.info(f"Starting {name} from {image}: {' '.join(args)}")
        self.container: DockerContainer = client.containers.create(
            image, args, name=name, network=network,
            ports={f"{port}/tcp": ("127.0.0.1", None) for port in ports or []},
            # a hardened container gets nothing it does not need
            read_only=hardened, cap_drop=["ALL"] if hardened else None, security_opt=["no-new-privileges"] if hardened else None,
            # the test of the image is kept, it is checked more often
            healthcheck={"interval": 5 * SECOND, "start_period": 5 * SECOND})
        try:
            if config is not None:
                self.put_file(config_path or "", config)
            self.container.start()
        except Exception:
            self.remove()
            raise

    def put_file(self, path: str, content: str) -> None:
        """Copy a file into the container, readable by its user."""
        data = content.encode()
        info = tarfile.TarInfo(pathlib.PurePosixPath(path).name)
        info.size = len(data)
        info.mode = 0o644
        archive = io.BytesIO()
        with tarfile.open(fileobj=archive, mode="w") as tar:
            tar.addfile(info, io.BytesIO(data))
        self.container.put_archive(str(pathlib.PurePosixPath(path).parent), archive.getvalue())

    def status(self) -> str:
        """The state and the health, `running healthy` when it is up."""
        self.container.reload()
        state = self.container.attrs["State"]
        return f"{state['Status']} {state.get('Health', {}).get('Status', '')}".strip()

    def wait_healthy(self, timeout: float = 120.0) -> None:
        deadline = time.monotonic() + timeout
        status = self.status()
        while time.monotonic() < deadline:
            status = self.status()
            if status == "running healthy":
                logger.info(f"{self.name} is healthy")
                return
            if not status.startswith("running"):
                break
            time.sleep(2)
        raise RuntimeError(f"{self.name} is {status}, not healthy\n{self.logs(30)}")

    def url(self, port: int) -> str:
        self.container.reload()
        return f"http://127.0.0.1:{self.container.ports[f'{port}/tcp'][0]['HostPort']}"

    def exec(self, *command: str) -> tuple[int, str]:
        """Run a command in the container and return its exit code and output."""
        result = self.container.exec_run(list(command))
        return result.exit_code, result.output.decode(errors="replace")

    def stop(self) -> int:
        """Stop it like docker stop does and return the exit code."""
        self.container.stop(timeout=30)
        self.container.reload()
        return self.container.attrs["State"]["ExitCode"]

    def logs(self, tail: int | str = "all") -> str:
        # the daemons log to stderr
        return self.container.logs(tail=tail).decode(errors="replace").strip()

    def remove(self) -> None:
        try:
            self.container.remove(v=True, force=True)
        except docker.errors.NotFound:
            pass


class Containers:
    """The containers and the network of a test, removed with their logs saved when it is done."""

    def __init__(self, label: str, logs_dir: pathlib.Path | None) -> None:
        self.label = label
        self.logs_dir = logs_dir
        self.prefix = f"image-tests-{uuid.uuid4().hex[:8]}"
        self.containers: list[Container] = []
        self.networks: list[Any] = []

    def network(self) -> str:
        network = client.networks.create(f"{self.prefix}-net")
        self.networks.append(network)
        return network.name

    def run(self, image: str, args: list[str], **kwargs: Any) -> Container:
        container = Container(image, args, f"{self.prefix}-{len(self.containers) + 1}", **kwargs)
        self.containers.append(container)
        return container

    def cleanup(self) -> None:
        for index, container in enumerate(self.containers, 1):
            if self.logs_dir is not None:
                self.logs_dir.mkdir(parents=True, exist_ok=True)
                path = self.logs_dir / f"{self.label}-{index}.log"
                path.write_text(container.logs())
                logger.info(f"Saved the log of {container.name} to {path}")
            container.remove()
        for network in self.networks:
            try:
                network.remove()
            except docker.errors.NotFound:
                pass
