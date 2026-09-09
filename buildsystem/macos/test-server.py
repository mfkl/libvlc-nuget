"""Serve synthetic media on an OS-allocated loopback port for CI playback."""
from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
import sys

with ThreadingHTTPServer(("127.0.0.1", 0), partial(SimpleHTTPRequestHandler, directory=sys.argv[1])) as server:
    Path(sys.argv[2]).write_text(str(server.server_port))
    server.serve_forever()
