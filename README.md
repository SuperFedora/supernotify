# SuperNotify

[![Release](https://img.shields.io/github/v/release/SuperFedora/supernotify?label=SuperNotify)](https://github.com/SuperFedora/supernotify/releases)
[![License: Apache 2.0](https://img.shields.io/badge/License-Apache_2.0-blue.svg)](LICENSE)

Standalone native Rust notification and full-screen `WARNING` controller (`supernotify`) for **[SuperFedora](https://superfedora.github.io/)**.

```bash
supernotify                                           # Launch interactive Notification TUI
supernotify send <title> [body]                       # Send top-center notification
supernotify warn [subtitle]                           # Trigger full-screen WARNING overlay
supernotify [status|history|dnd|clear|dismiss|center|tui]
```

* **Top-Center Notifications:** Minimal theme-matched popups directly beneath the top-bar Notification Bell.
* **Full-Screen `WARNING`:** Classic Mega Man X rhythmic red strobe alert overlay across the entire screen.

**Full documentation & keybinding reference: [superfedora.github.io](https://superfedora.github.io/)**

Licensed under the Apache License, Version 2.0.
