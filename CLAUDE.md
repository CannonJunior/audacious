# Project Guidelines

## No Hardcoding

Never hardcode values that reflect runtime state (connection status, server URLs,
port numbers, counts, etc.). These must always be driven by actual signals, API
calls, or live data — not baked into scene files or GDScript as static strings.
