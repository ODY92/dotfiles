# Dynamic Island for Caelestia

Upstream: https://github.com/fedyaqq34356/hyprdots
Commit: 1543aa80b59ef416428a89cf2f58fc90b6e62e0e
License: GPL-3.0 (see LICENSE)

This copy uses an island-only shell.qml. The original entry point is preserved
as shell.upstream.qml. Do not launch that entry point alongside Caelestia.

The island follows ~/.config/caelestia/bar-enabled: off loads the island,
on unloads it. barpos keeps the previous bar position in bar-position.
Caelestia forwards notification content to the bridge IPC target.

The helper paths point inside this directory. The upstream cava configuration
is helpers/cava.conf. No complete hyprdots desktop installer was run.
The upstream startup GTA teaser, sounds, weather and printer integration are
disabled by default. Other island modules retain their upstream implementation.

Settings: qs -c dynamic-island ipc call bridge configure
State: qs -c dynamic-island ipc call bridge state

Notification action buttons and inline replies are not forwarded by the
content-only notification bridge. The Caelestia notification center is retained.
