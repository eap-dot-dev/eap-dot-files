# ——— Instant Prompt (Powerlevel10k) ———
# This should appear before anything that produces output or blocks initialization.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

if command -v brew &>/dev/null && [ -f "$(brew --prefix)/opt/zinit/zinit.zsh" ]; then
  source "$(brew --prefix)/opt/zinit/zinit.zsh"
elif [ -f "${HOME}/.local/share/zinit/zinit.zsh" ]; then
  source "${HOME}/.local/share/zinit/zinit.zsh"
else
  echo "Warning: Zinit not found — plugin commands won’t work."
fi

# ——— Initialize zsh Completion System ———
autoload -Uz compinit
compinit -i

# ——— Plugin / Prompt / Zinit Setup ———

# Minimal depth load of Powerlevel10k to speed prompt
zinit ice depth=1
zinit light romkatv/powerlevel10k

# Completions plugin (defers compinit replay)
zinit ice wait lucid atinit"zicompinit; zicdreplay"
zinit light zsh-users/zsh-completions

# Autosuggestions plugin
zinit ice wait lucid atload"_zsh_autosuggest_start"
zinit light zsh-users/zsh-autosuggestions

# Syntax highlighting plugin
zinit ice wait lucid
zinit light zsh-users/zsh-syntax-highlighting

if command -v fzf &>/dev/null; then
  # Check if `fzf` supports --completion flag
  if fzf --help 2>&1 | grep -q -- "--completion"; then
    source <(fzf --completion) 2>/dev/null || true
  fi
fi

# ——— ASDF Integration ———
if command -v brew &>/dev/null && [ -f "$(brew --prefix)/opt/asdf/libexec/asdf.sh" ]; then
  . "$(brew --prefix)/opt/asdf/libexec/asdf.sh"
  if [ -f "$(brew --prefix)/opt/asdf/libexec/completions/asdf.zsh" ]; then
    . "$(brew --prefix)/opt/asdf/libexec/completions/asdf.zsh"
  fi
elif [ -f "${HOME}/.asdf/asdf.sh" ]; then
  . "${HOME}/.asdf/asdf.sh"
  if [ -f "${HOME}/.asdf/completions/asdf.zsh" ]; then
    . "${HOME}/.asdf/completions/asdf.zsh"
  fi
fi

# ——— Ghostty Integration ———
if [[ -n ${GHOSTTY_RESOURCES_DIR:-} ]]; then
  source "${GHOSTTY_RESOURCES_DIR}/shell-integration/zsh/ghostty-integration"
fi

# ——— Custom Prompt Overrides / Segments ———
if [[ -f "${HOME}/.eap-dot-files/zsh/custom-prompt.zsh" ]]; then
  source "${HOME}/.eap-dot-files/zsh/custom-prompt.zsh"
fi

# ——— Replay Deferred compdef Commands ———
zinit cdreplay -q

# ——— Load Powerlevel10k Configuration ———
# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh