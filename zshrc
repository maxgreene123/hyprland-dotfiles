typeset -U path
path=("$HOME/.local/bin" $path)

# pnpm
export PNPM_HOME="$HOME/.local/share/pnpm"
path=("$PNPM_HOME/bin" $path)

export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="robbyrussell"
plugins=(git)
source "$ZSH/oh-my-zsh.sh"

zstyle ':completion:*' menu select
ZSH_AUTOSUGGEST_STRATEGY=(history completion)

# Load highlighting last.
for plugin in zsh-autosuggestions zsh-syntax-highlighting; do
    [[ -r /usr/share/zsh/plugins/$plugin/$plugin.zsh ]] && source /usr/share/zsh/plugins/$plugin/$plugin.zsh
done
