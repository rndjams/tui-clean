# tui-clean

Strips TUI rendering artifacts from clipboard content — ANSI sequences, box-padding bleed, soft-wrapped line splits, URL click-wrap, and OSC 8 hyperlink extraction.

The core tool is shell-agnostic. A zsh plugin ships for automatic paste interception; other shells can use `fixclip` manually today, with hookpoints for bash and fish documented below.

## The Problem

AI coding assistants (Kiro CLI, GSD, Claude Code) render responses in styled panels. When you copy output and paste into a terminal, artifacts corrupt the content:

**Box-padding bleed.** Code blocks are indented by the panel renderer. Every interior line carries that prefix — heredocs and shell commands arrive syntactically broken:

```
# What Cmd+V delivers from an AI TUI tool:
cat > ~/.config/app/config << 'EOF'
  [settings]
  timeout = 30
EOF
```

**Soft-wrap line splits.** Lines that exceed the render width are split at the column boundary. A single expression arrives as two lines — a syntax error if run directly:

```
  session_valid = python3 -c "import os,time; exit(0 if ... + 7200
  else 1)"
```

**URL click-wrap.** Long URLs are soft-wrapped at the column boundary. CMD+click (macOS) or Ctrl+click opens only the truncated first fragment — auth flows (CAZ, OAuth MCP re-auth) silently fail. The kiro-cli `/copy` path is no help since the copied URL is also cut:

```
# TUI wraps at column 80; click opens https://github.com/example/repo/issues/123?q=is%3Aopen+label%3Abug ✗
See: https://github.com/example/repo/issues/123?q=is%3Aopen+la
bel%3Abug+assignee%3Aoctocat
```

## The Fix

```
# Before (pasted from Kiro CLI):          # After (tui-clean):
cat > ~/.config/app/config << 'EOF'       cat > ~/.config/app/config << 'EOF'
  [settings]                              [settings]
  timeout = 30                            timeout = 30
EOF                                       EOF

# Broken URL split:                       # Rejoined:
https://github.com/example/repo/issues/1  https://github.com/example/repo/issues/1234
234
```

## Installation

### zsh (auto-clean on every paste)

```zsh
# zinit
zinit light rndjams/tui-clean

# antidote
antidote bundle rndjams/tui-clean

# sheldon
sheldon add tui-clean --github rndjams/tui-clean

# oh-my-zsh (custom plugin)
git clone https://github.com/rndjams/tui-clean ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/tui-clean
# add tui-clean to plugins=(...) in .zshrc

# manual
git clone https://github.com/rndjams/tui-clean ~/.tui-clean
echo 'source ~/.tui-clean/tui-clean.plugin.zsh' >> ~/.zshrc
```

### Any shell (manual / scripting)

```sh
# put bin/tui-clean on $PATH, then:
fixclip                        # alias: clean clipboard in-place
pbpaste | tui-clean -          # stdin → stdout
tui-clean --print              # clipboard in, stdout out
tui-clean --width 120          # explicit terminal width
```

## Shell Support

| Shell | Auto-paste hook | `fixclip` / pipeline |
|-------|----------------|----------------------|
| zsh   | ✅ ships here (ZLE `bracketed-paste` override) | ✅ |
| bash  | ⚙ possible via readline `paste-start`/`paste-end` — PR welcome | ✅ |
| fish  | ⚙ possible via `fish_clipboard_paste` override — PR welcome | ✅ |
| other | — | ✅ |

The auto-hook is the main convenience win. On bash and fish the equivalent hookpoints exist; the implementation just hasn't been written yet. `fixclip` works everywhere in the meantime.

## Configuration

| Variable | Effect |
|---|---|
| `TUI_CLEAN_NO_PASTE_HOOK=1` | Load the plugin without overriding bracketed-paste |

Set before sourcing the plugin if you want `tui-clean` on `$PATH` and `fixclip` available, but prefer to manage the paste hook yourself.

## How it works

Five-stage pipeline applied to every paste:

1. **OSC 8 extraction** — parses terminal hyperlink sequences (`\x1b]8;;URI\x07display\x1b]8;;\x07`) and replaces them with the canonical URI from the params field. The URI is never soft-wrapped by the renderer; the display text is. Handles both BEL and ST terminators; falls back to display text for non-HTTP schemes (e.g. `mailto:`).

2. **ANSI strip** — removes remaining CSI, OSC, G0/G1 charset, and bare carriage-returns.

3. **Box-indent removal** — finds the most common non-zero indent across non-empty lines (threshold: ≥ 30% of lines must share it). Strips that prefix from lines that carry it; leaves unindented anchor lines like `EOF` untouched.

4. **Soft-wrap rejoin** — estimates terminal width from the longest line (floor: 60 chars — AI TUI panes can be narrower than 80). Joins lines that hit the margin or end mid-expression (`&&`, `<`, `,`, `(`, etc.), stopping when the accumulated line looks syntactically closed.

5. **Mid-URL break rejoin** — independent of terminal width estimate. Fires when a line ends with a URL extending to EOL (`https?://\S+$`) AND the next line's leading token consists entirely of URL-safe characters and contains at least one URL-specific character (digit, `%`, `?`, `&`, `=`, `/`...). This distinguishes real URL tails like `12345` or `%2Fcallback` from prose words like `for` or `the`. Joins without a space separator.

The zsh hook uses a before/after `LBUFFER` diff to extract exactly what was pasted, transforms it, and replaces it — falling back to the original paste on any error.

## Requirements

- Python 3.8+ (ships with macOS Monterey+; pre-installed on most Linux distros)
- zsh 5.1+ for the paste hook

## Warp

Warp's input block bypasses the bracketed-paste protocol, so the ZLE hook does not fire there. Use `fixclip` before pasting, or track the upstream feature request:

- [warpdotdev/warp#11608: Feature request — `paste_transform` config hook](https://github.com/warpdotdev/warp/issues/11608)

## Upstream context

`tui-clean` is a downstream workaround. The correct fix is for TUI tools to write clipboard content via **OSC 52** (raw message text, not rendered buffer), and emit URLs via **OSC 8** hyperlinks so click targets are never truncated by column wrapping. Issues filed:

- [open-gsd/gsd-pi#69: Use OSC 52 for TUI copy](https://github.com/open-gsd/gsd-pi/issues/69)
- [warpdotdev/warp#11608: paste_transform config hook](https://github.com/warpdotdev/warp/issues/11608)

## License

MIT
