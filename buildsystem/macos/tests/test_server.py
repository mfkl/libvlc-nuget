"""The playback fixture server must start without resolving the runner hostname."""
from functools import partial
from http.server import SimpleHTTPRequestHandler
import importlib.util
from pathlib import Path
import tempfile
import threading
import unittest
from unittest.mock import patch
from urllib.request import urlopen

spec = importlib.util.spec_from_file_location(
    "fixture_server", Path(__file__).resolve().parents[1] / "test-server.py")
fixture_server = importlib.util.module_from_spec(spec)
spec.loader.exec_module(fixture_server)


class FixtureServerTests(unittest.TestCase):
    def test_serves_fixture_without_dns(self):
        with tempfile.TemporaryDirectory() as directory:
            data = b"synthetic media fixture"
            Path(directory, "sample.mp4").write_bytes(data)
            handler = partial(SimpleHTTPRequestHandler, directory=directory)
            with patch("socket.getfqdn", side_effect=AssertionError("Unexpected DNS lookup")):
                with fixture_server.LoopbackServer(("127.0.0.1", 0), handler) as server:
                    thread = threading.Thread(target=server.serve_forever)
                    thread.start()
                    try:
                        with urlopen(f"http://127.0.0.1:{server.server_port}/sample.mp4", timeout=5) as response:
                            self.assertEqual(response.read(), data)
                    finally:
                        server.shutdown()
                        thread.join(timeout=5)


if __name__ == "__main__":
    unittest.main()
