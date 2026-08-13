#!/usr/bin/env python3
"""
HTTP server for the Godot scene inspector web app.

Serves index.html on port 8787. WebKit2 off-screen rendering is attempted
optionally; if GTK/WebKit2 is unavailable (e.g. Wayland without the libs)
the HTTP server still runs and the browser page connects via WebSocket as
normal.
"""

import os, sys, threading, functools
from http.server import HTTPServer, SimpleHTTPRequestHandler

WIDTH      = int(sys.argv[1]) if len(sys.argv) > 1 else 600
HEIGHT     = int(sys.argv[2]) if len(sys.argv) > 2 else 800
HTTP_PORT  = 8787
FRAME_PATH = '/tmp/godot_webview_frame.png'

# ── HTTP server ───────────────────────────────────────────────────────────────

_serve_dir = os.path.dirname(os.path.abspath(__file__))

class _QuietHandler(SimpleHTTPRequestHandler):
    def log_message(self, format: str, *args: object) -> None:  # noqa: ARG002
        pass

def _run_http():
    handler = functools.partial(_QuietHandler,
                                directory=_serve_dir,
                                )
    try:
        srv = HTTPServer(('127.0.0.1', HTTP_PORT), handler)
        srv.serve_forever()
    except OSError:
        pass  # port already held by a previous run

http_thread = threading.Thread(target=_run_http, daemon=False)
http_thread.start()

# ── WebKit off-screen renderer (optional) ────────────────────────────────────

_webkit_ok = False
try:
    os.environ.setdefault('WEBKIT_DISABLE_COMPOSITING_MODE', '1')
    import gi
    gi.require_version('Gtk', '3.0')
    gi.require_version('WebKit2', '4.1')
    from gi.repository import Gtk, WebKit2, GLib  # type: ignore[attr-defined]

    _win = Gtk.OffscreenWindow()
    _win.set_default_size(WIDTH, HEIGHT)

    _webview = WebKit2.WebView()
    _webview.set_size_request(WIDTH, HEIGHT)
    _webview.load_uri(f'http://127.0.0.1:{HTTP_PORT}/')
    _win.add(_webview)
    _win.show_all()

    def _export_frame():
        pixbuf = _win.get_pixbuf()
        if pixbuf:
            pixbuf.savev(FRAME_PATH, 'png', [], [])
        return True

    GLib.timeout_add(100, _export_frame)
    _webkit_ok = True
except Exception:
    pass

if _webkit_ok:
    Gtk.main()  # type: ignore[possibly-undefined]
else:
    # Keep process alive so Godot can kill it on exit.
    http_thread.join()
