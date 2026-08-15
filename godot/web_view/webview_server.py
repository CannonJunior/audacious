#!/usr/bin/env python3
"""
HTTP + WebKit2 off-screen renderer for Godot web-view panels.

Serves all files under web_view/ on port 8787 so the same HTML is reachable
from a regular browser for design iteration.

When GTK/WebKit2 is available, renders up to three off-screen panels and
exports frames as PNGs that Godot reads back as live textures:

  /tmp/godot_webview_frame.png       — scene inspector  (index.html)
  /tmp/godot_power_router.png        — power router     (power_router.html)
  /tmp/godot_gas_router.png          — gas router       (gas_router.html)

If GTK/WebKit2 is unavailable the HTTP server still runs, so the browser
workflow continues to work normally.
"""

import os, sys, time, threading, functools
from http.server import HTTPServer, SimpleHTTPRequestHandler

HTTP_PORT  = int(sys.argv[3]) if len(sys.argv) > 3 else 8787
FRAME_PATH       = '/tmp/godot_webview_frame.png'
POWER_FRAME_PATH = '/tmp/godot_power_router.png'
GAS_FRAME_PATH   = '/tmp/godot_gas_router.png'

FAST_MS        = 33     # ~30 fps while a panel is open
IDLE_MS        = 500    # 2 fps when nothing is watching
_DEMAND_PATH   = '/tmp/godot_webview_demand'
_ACTIVE_WINDOW = 3.0    # seconds after last touch before dropping to idle

# Legacy size args kept for backward compatibility (used by the inspector panel).
INSP_W = int(sys.argv[1]) if len(sys.argv) > 1 else 600
INSP_H = int(sys.argv[2]) if len(sys.argv) > 2 else 800

POWER_W, POWER_H = 580, 580
GAS_W,   GAS_H   = 560, 570

# ── HTTP server ───────────────────────────────────────────────────────────────

_serve_dir = os.path.dirname(os.path.abspath(__file__))

class _QuietHandler(SimpleHTTPRequestHandler):
    def log_message(self, format: str, *args: object) -> None:  # noqa: ARG002
        pass

def _run_http():
    handler = functools.partial(_QuietHandler, directory=_serve_dir)
    try:
        srv = HTTPServer(('127.0.0.1', HTTP_PORT), handler)
        srv.serve_forever()
    except OSError:
        pass  # port already held by a previous run

threading.Thread(target=_run_http, daemon=False).start()

# ── WebKit2 off-screen renderer (optional) ────────────────────────────────────

_webkit_ok = False
try:
    os.environ.setdefault('WEBKIT_DISABLE_COMPOSITING_MODE', '1')
    import gi
    gi.require_version('Gtk', '3.0')
    gi.require_version('WebKit2', '4.1')
    from gi.repository import Gtk, WebKit2, GLib  # type: ignore[attr-defined]

    def _make_panel(url: str, w: int, h: int) -> tuple:
        """Return (OffscreenWindow, WebView) sized w×h loading url."""
        win = Gtk.OffscreenWindow()
        win.set_default_size(w, h)
        wv = WebKit2.WebView()
        wv.set_size_request(w, h)
        wv.load_uri(url)
        win.add(wv)
        win.show_all()
        return win, wv

    base = f'http://127.0.0.1:{HTTP_PORT}'
    _insp_win,  _ = _make_panel(f'{base}/',                 INSP_W,  INSP_H)
    _power_win, _ = _make_panel(f'{base}/power_router.html', POWER_W, POWER_H)
    _gas_win,   _ = _make_panel(f'{base}/gas_router.html',   GAS_W,   GAS_H)

    _current_ms = [IDLE_MS]

    def _export_frames() -> bool:
        try:
            active = time.time() - os.path.getmtime(_DEMAND_PATH) < _ACTIVE_WINDOW
        except OSError:
            active = False

        target_ms = FAST_MS if active else IDLE_MS

        for win, path in (
            (_insp_win,  FRAME_PATH),
            (_power_win, POWER_FRAME_PATH),
            (_gas_win,   GAS_FRAME_PATH),
        ):
            pb = win.get_pixbuf()
            if pb:
                pb.savev(path, 'png', [], [])

        if target_ms != _current_ms[0]:
            _current_ms[0] = target_ms
            GLib.timeout_add(target_ms, _export_frames)
            return False  # cancel this timer; replacement is scheduled

        return True  # reschedule at same interval

    GLib.timeout_add(IDLE_MS, _export_frames)
    _webkit_ok = True

except Exception:
    pass

if _webkit_ok:
    Gtk.main()  # type: ignore[possibly-undefined]
else:
    # Keep process alive so Godot can kill it on exit.
    threading.Event().wait()
