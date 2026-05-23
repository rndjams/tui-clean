# tui-clean — strip TUI rendering artifacts on paste
#
# Overrides the bracketed-paste ZLE widget so every terminal paste is
# automatically cleaned. Fixes:
#   - OSC 8 hyperlinks   : canonical URI extracted from params (never soft-wrapped)
#   - Box-padding bleed  : panel indent stripped from copied code/text
#   - Soft-wrap splits   : lines rejoined using terminal-width heuristic
#   - Mid-URL breaks     : URL fragments rejoined regardless of line length
#
# Works transparently in iTerm2, Ghostty, kitty, and any terminal that
# delivers paste via the bracketed-paste protocol.
#
# Warp note: Warp's input block bypasses bracketed-paste. Use `fixclip`
# there, or track the upstream feature request (warpdotdev/warp#11608).
#
# Usage:
#   source tui-clean.plugin.zsh   # manual
#   zinit light rndjams/tui-clean # zinit

# Guard against double-sourcing
(( _TUI_CLEAN_LOADED )) && return
_TUI_CLEAN_LOADED=1

# Add bin/ to PATH so `tui-clean` is available as a standalone command
_TUI_CLEAN_DIR="${0:A:h}"
path=("$_TUI_CLEAN_DIR/bin" $path)

# Override bracketed-paste to auto-clean every paste in the terminal.
# Technique: let .bracketed-paste insert normally, extract what was inserted
# (LBUFFER diff), pipe through tui-clean, replace with cleaned version.
# Falls back to original paste on any error — never silently drops input.
if [[ -z "$TUI_CLEAN_NO_PASTE_HOOK" ]]; then
  bracketed-paste() {
    local before="$LBUFFER" rbefore="$RBUFFER"
    zle .bracketed-paste
    local pasted="${LBUFFER:${#before}}"
    if [[ -n "$pasted" ]]; then
      LBUFFER="$before"
      RBUFFER="$rbefore"
      local cleaned
      cleaned=$(printf '%s' "$pasted" | tui-clean - 2>/dev/null)
      LBUFFER+="${cleaned:-$pasted}"
    fi
  }
  zle -N bracketed-paste
fi

# fixclip: clean clipboard in-place for paste targets that bypass ZLE
# (Warp, editors, GUI apps). Reads pbpaste, cleans, writes back via pbcopy.
alias fixclip='tui-clean'
