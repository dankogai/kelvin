"""tests/fetch/server.py PORTFILE [CERT KEY] (#482): the server that
tests/fetch.sh fetches from, on 127.0.0.1 at a free port, which it writes to
PORTFILE; HTTPS with CERT and KEY. Each path answers one way a server may;
any method is taken (#483), and /method echoes the request.
"""
import faulthandler
import http.server
import socketserver
import ssl
import sys
import time


class Handler(http.server.BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"

    def log_message(self, *args):
        pass

    def send(self, status, body, headers=(), length=True):
        self.send_response(status)
        for k, v in headers:
            self.send_header(k, v)
        if length:
            self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        if self.command != "HEAD":
            self.wfile.write(body)

    # any method, as written: do_GET, do_POST, do_patch, ...
    def __getattr__(self, name):
        if name.startswith("do_"):
            return self.answer
        raise AttributeError(name)

    def answer(self):
        n = int(self.headers.get("Content-Length") or 0)
        self.sent = self.rfile.read(n) if n else b""
        p = self.path
        port = self.server.server_address[1]
        if p == "/method":
            h = self.headers
            text = "%s|%s|%s|%s|%s|%s|%s\n" % (
                self.command, self.sent.decode("latin-1"), h.get("Content-Type"), h.get("Content-Length"),
                h.get("X-Custom"), h.get("Authorization"), h.get("User-Agent"))
            self.send(200, text.encode("latin-1"), [("X-Method", self.command)])
            return
        if p in ("/301", "/302", "/303", "/307", "/308"):
            self.send(int(p[1:]), b"", [("Location", "/method")])
            return
        if p == "/elsewhere":  # the same server by another name: another origin
            self.send(307, b"", [("Location", "http://localhost:%d/method" % port)])
            return
        self.do_get()

    def do_get(self):
        p = self.path
        if p == "/hello":
            self.send(200, b"hello, fetch\n", [("Content-Type", "text/plain; charset=utf-8")])
        elif p == "/query?a=1&b=2":
            self.send(200, b"the query came\n")
        elif p == "/redirect":
            self.send(302, b"", [("Location", "/hello")])
        elif p == "/dir/relative":
            self.send(301, b"", [("Location", "../hello")])
        elif p == "/hello/../hello" or p == "/dir/../hello":
            self.send(200, b"hello, fetch\n")
        elif p == "/twice":
            self.send(307, b"", [("Location", "/redirect")])
        elif p == "/loop":
            self.send(302, b"", [("Location", "/loop")])
        elif p == "/missing":
            self.send(404, b"no such page\n", [("Content-Type", "text/plain")])
        elif p == "/chunked":
            self.send_response(200)
            self.send_header("Transfer-Encoding", "chunked")
            self.end_headers()
            for piece in (b"chunk one, ", b"chunk two", b"\n"):
                self.wfile.write(b"%x\r\n%s\r\n" % (len(piece), piece))
            self.wfile.write(b"0\r\n\r\n")
        elif p == "/bytes":
            self.send(200, b"\xff\x00\x01", [("Content-Type", "application/octet-stream")])
        elif p == "/headers":
            self.send(200, b"", [("X-Twice", "a"), ("X-Twice", "b"), ("X-Mixed-Case", "Value Kept")])
        elif p == "/empty":
            self.send(204, b"", length=False)
        elif p == "/close":
            self.send_response(200)
            self.send_header("Connection", "close")
            self.end_headers()
            self.wfile.write(b"until the end\n")
            self.close_connection = True
        elif p == "/echo":
            host = self.headers.get("Host")
            if host == "127.0.0.1:%d" % self.server.server_address[1]:
                host = "host"
            text = "%s %s|%s|%s\n" % (self.command, self.path, host, self.headers.get("User-Agent"))
            self.send(200, text.encode())
        elif p == "/json":
            self.send(200, b'{"name": "kelvin", "tags": ["c", 11], "ok": true, "none": null}',
                      [("Content-Type", "application/json")])
        elif p == "/badjson":
            self.send(200, b'[1, 2', [("Content-Type", "application/json")])
        elif p == "/slow":  # an answer a second late
            time.sleep(1.0)
            self.send(200, b"late\n")
        elif p == "/trickle":  # a byte every 0.2 seconds, 10 in all
            self.send_response(200)
            self.send_header("Content-Length", "10")
            self.end_headers()
            for _ in range(10):
                time.sleep(0.2)
                self.wfile.write(b"x")
                self.wfile.flush()
        elif p == "/slowredirect":  # a redirect after half a second, to /slow
            time.sleep(0.5)
            self.send(302, b"", [("Location", "/slow")])
        elif p == "/latin1":
            self.send(200, b"", [("X-Name", "caf\xe9".encode("latin-1").decode("latin-1"))])
        else:
            self.send(404, b"")


class Server(socketserver.ThreadingMixIn, http.server.HTTPServer):
    daemon_threads = True
    allow_reuse_address = True

    # HTTPServer's asks socket.getfqdn for its name, a lookup of DNS that
    # may take seconds where a CI runner's resolver is slow
    def server_bind(self):
        socketserver.TCPServer.server_bind(self)
        self.server_name = "127.0.0.1"
        self.server_port = self.server_address[1]


def step(what):
    print("server.py:", what, file=sys.stderr, flush=True)


def main():
    # where a start that is slow waits, in the log tests/fetch.sh shows
    faulthandler.dump_traceback_later(8, exit=False)
    step("Python %s, %s" % (sys.version.split()[0], ssl.OPENSSL_VERSION))
    server = Server(("127.0.0.1", 0), Handler)
    step("listening")
    if len(sys.argv) > 3:
        ctx = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
        step("TLS context made")
        ctx.load_cert_chain(sys.argv[2], sys.argv[3], password=lambda: b"")  # never a prompt
        step("certificate loaded")
        server.socket = ctx.wrap_socket(server.socket, server_side=True)
        step("TLS on")
    with open(sys.argv[1] + ".tmp", "w") as f:
        f.write(str(server.server_address[1]))
    import os
    os.rename(sys.argv[1] + ".tmp", sys.argv[1])
    faulthandler.cancel_dump_traceback_later()
    server.serve_forever()


main()
