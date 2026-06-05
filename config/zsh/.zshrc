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
  echo "Warning: Zinit not found — plugin commands won't work."
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
  source <(fzf --zsh) 2>/dev/null || true
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

# ——— Secrets / Environment Variables ———
# Load sensitive environment variables (API keys, tokens, etc.)
# This file is not tracked in git
if [[ -f "${HOME}/.secrets.sh" ]]; then
  source "${HOME}/.secrets.sh"
fi

# ——— Work Environment ———
DOTFILES_DIR="${HOME}/Development/eap-dot-files"
if [[ -f "${DOTFILES_DIR}/config/zsh/work.zsh" ]]; then
  source "${DOTFILES_DIR}/config/zsh/work.zsh"
fi

# ——— OrbStack ———
if [[ -f "${HOME}/.orbstack/shell/init.zsh" ]]; then
  source "${HOME}/.orbstack/shell/init.zsh" 2>/dev/null
fi

# pnpm
if [[ "$OSTYPE" == darwin* ]]; then
  export PNPM_HOME="$HOME/Library/pnpm"
else
  export PNPM_HOME="$HOME/.local/share/pnpm"
fi
case ":$PATH:" in
  *":$PNPM_HOME/bin:"*) ;;
  *) export PATH="$PNPM_HOME/bin:$PATH" ;;
esac
# pnpm end

# ——— Local binaries (Claude Code, etc.) ———
case ":$PATH:" in
  *":$HOME/.local/bin:"*) ;;
  *) export PATH="$HOME/.local/bin:$PATH" ;;
esac

# ——— Homebrew keg-only tools ———
# libpq: PostgreSQL client tools (psql, pg_dump, etc.) without full server install
if [[ -d "/opt/homebrew/opt/libpq/bin" ]]; then
  export PATH="/opt/homebrew/opt/libpq/bin:$PATH"
fi

# ——— Replay Deferred compdef Commands ———
zinit cdreplay -q

# ——— Load Powerlevel10k Configuration ———
# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

if [[ "$OSTYPE" == darwin* ]]; then
  alias ls='ls -G'
else
  alias ls='ls --color=auto'
fi

# Added by Antigravity
case ":$PATH:" in
  *":$HOME/.antigravity/antigravity/bin:"*) ;;
  *) export PATH="$HOME/.antigravity/antigravity/bin:$PATH" ;;
esac

# Fix Node.js TLS cert verification — use macOS system CA bundle
export NODE_EXTRA_CA_CERTS=/etc/ssl/cert.pem
export PATH=$PATH:$HOME/.maestro/bin
