# Path to your oh-my-zsh installation.
#export ZSH="$HOME/.oh-my-zsh"
export ZSH="$HOME/.config/zsh/ohmyzsh"
ZSH_THEME="essembeh"

# Which plugins would you like to load?
# Standard plugins can be found in $ZSH/plugins/
# Custom plugins may be added to $ZSH_CUSTOM/plugins/
# Example format: plugins=(rails git textmate ruby lighthouse)
# Add wisely, as too many plugins slow down shell startup.
plugins=(git)

if type brew &>/dev/null; then
  FPATH=$(brew --prefix)/share/zsh/site-functions:$FPATH

  autoload -Uz compinit
  compinit
fi
export PATH="/usr/local/opt/openjdk/bin:$PATH"

source $ZSH/oh-my-zsh.sh
