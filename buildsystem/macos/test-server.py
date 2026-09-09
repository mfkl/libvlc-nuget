"""Serve synthetic media on an OS-allocated loopback port for CI playback."""
from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from socketserver import TCPServer
import sys


class LoopbackServer(ThreadingHTTPServer):
    def server_bind(self):
        # HTTPServer.server_bind calls getfqdn, which can block on runner DNS.
        # This fixture server only listens on loopback and needs no DNS lookup.
        TCPServer.server_bind(self)
        self.server_name = "localhost"
        self.server_port = self.server_address[1]


if __name__ == "__main__":
    with LoopbackServer(("127.0.0.1", 0), partial(SimpleHTTPRequestHandler, directory=sys.argv[1])) as server:
        port_file = Path(sys.argv[2])
        temporary = port_file.with_suffix(".tmp")
        temporary.write_text(str(server.server_port))
        temporary.replace(port_file)
        server.serve_forever()
