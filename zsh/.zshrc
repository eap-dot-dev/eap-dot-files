# ——— ZINIT BOOTSTRAP ———
if [ -f "$(brew --prefix)/opt/zinit/zinit.zsh" ]; then
  source "$(brew --prefix)/opt/zinit/zinit.zsh"
fi

# ——— Instant Prompt (Powerlevel10k) ———
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# ——— CORE / PLUGINS ———
zinit ice depth=1
zinit light romkatv/powerlevel10k

zinit ice wait lucid atinit"zicompinit; zicdreplay"
zinit light zsh-users/zsh-completions

zinit ice wait lucid atload"_zsh_autosuggest_start"
zinit light zsh-users/zsh-autosuggestions

zinit ice wait lucid
zinit light zsh-users/zsh-syntax-highlighting

# ——— ZSH OPTIONS / HISTORY ———
HISTFILE=~/.zsh_history
HISTSIZE=10000
SAVEHIST=10000
setopt HIST_IGNORE_DUPS
setopt HIST_IGNORE_ALL_DUPS
setopt HIST_FIND_NO_DUPS
setopt HIST_SAVE_NO_DUPS
setopt EXTENDED_HISTORY

# ASDF integration (source brew version)
if command -v brew &>/dev/null; then
  ASDF_LIBEXEC="$(brew --prefix asdf)/libexec"
  if [ -f "$ASDF_LIBEXEC/asdf.sh" ]; then
    . "$ASDF_LIBEXEC/asdf.sh"
  fi
  if [ -f "$ASDF_LIBEXEC/completions/asdf.zsh" ]; then
    . "$ASDF_LIBEXEC/completions/asdf.zsh"
  fi
fi

# ——— FZF integration ———
if command -v fzf &>/dev/null; then
  source <(fzf --completion) 2>/dev/null || true
  export FZF_DEFAULT_COMMAND='fd --type f --hidden --follow --exclude .git'
  export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
fi

# ——— Ghostty integration ———
if [[ -n ${GHOSTTY_RESOURCES_DIR:-} ]]; then
  source "${GHOSTTY_RESOURCES_DIR}/shell-integration/zsh/ghostty-integration"
fi

# ——— End of rc ———
zinit cdreplay -q

# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh
