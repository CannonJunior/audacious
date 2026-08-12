#!/usr/bin/env python3
"""
Off-screen WebKit2 renderer + HTTP server for the Godot scene inspector.

Renders http://localhost:8787/ inside a Gtk.OffscreenWindow (no visible
window, no display dependency beyond GTK initialising) and writes PNG
frames to FRAME_PATH every 100 ms for Godot to read as a texture.

The HTTP server is embedded here so this single process replaces the
separate python3 -m http.server invocation used previously.
"""

import os, sys, threading, functools

# Force software compositing so WebKit2 renders into the offscreen surface.
os.environ.setdefault('WEBKIT_DISABLE_COMPOSITING_MODE', '1')

import gi
gi.require_version('Gtk', '3.0')
gi.require_version('WebKit2', '4.1')
from gi.repository import Gtk, WebKit2, GLib

from http.server import HTTPServer, SimpleHTTPRequestHandler

WIDTH      = int(sys.argv[1]) if len(sys.argv) > 1 else 600
HEIGHT     = int(sys.argv[2]) if len(sys.argv) > 2 else 800
HTTP_PORT  = 8787
FRAME_PATH = '/tmp/godot_webview_frame.png'

# ── HTTP server ───────────────────────────────────────────────────────────────

_serve_dir = os.path.dirname(os.path.abspath(__file__))

def _run_http():
    handler = functools.partial(SimpleHTTPRequestHandler,
                                directory=_serve_dir)
    try:
        srv = HTTPServer(('127.0.0.1', HTTP_PORT), handler)
        srv.serve_forever()
    except OSError:
        pass  # port already held by a previous run — that server keeps serving

threading.Thread(target=_run_http, daemon=True).start()

# ── WebKit off-screen renderer ────────────────────────────────────────────────

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
    return True  # keep the GLib timer alive

GLib.timeout_add(100, _export_frame)
Gtk.main()
