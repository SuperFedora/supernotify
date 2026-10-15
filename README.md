# SuperNotify

[![Release](https://img.shields.io/github/v/release/SuperFedora/supernotify?label=SuperNotify)](https://github.com/SuperFedora/supernotify/releases)
[![License: Apache 2.0](https://img.shields.io/badge/License-Apache_2.0-blue.svg)](LICENSE)

Standalone native Rust 16-bit Cast Comms, animated pixel-art character roster (10 specialists), and arcade banner controller (`supernotify`) for **[SuperFedora](https://superfedora.github.io/)**.

```bash
supernotify                                           # Launch interactive 16-bit Cast & Banner TUI
supernotify cast [ai|security|builder|engineer|app|navigator|medic|archivist|commander|synth|all]
supernotify --cast <role> [title] [body]              # Trigger animated 16-bit character comms popup
supernotify --banner <ready|warning|update|checkpoint> [subtitle]
supernotify [status|roster|history|dnd|clear|dismiss|center|send|sync-cast|tui]
```

* **Cast Roster (10 Animated 16-Bit Specialists):** `ai`, `security`, `builder`, `engineer`, `app`, `navigator`, `medic`, `archivist`, `commander`, `synth`.
* **Binary & Assets:** Installed to `~/.local/bin/supernotify` and `~/.config/superfedora/cast/*.svg`.

**Full documentation & keybinding reference: [superfedora.github.io](https://superfedora.github.io/)**

Licensed under the Apache License, Version 2.0.
