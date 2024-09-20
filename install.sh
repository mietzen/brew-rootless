#!/bin/zsh

mkdir -p $HOME/.local/opt
mkdir -p $HOME/Applications
git clone https://github.com/mietzen/brew-rootless.git $HOME/.local/opt/homebrew
cat << EOF >> $HOME/.zshrc

### ROOTLESS-BREW
# Homebrew Binary
export PATH="$HOME/.local/opt/homebrew/bin:$PATH"

## Brew Auto-Completions
if type brew &>/dev/null
then
    FPATH="$(brew --prefix)/share/zsh/site-functions:${FPATH}"
    autoload -Uz compinit
    compinit
fi
### ROOTLESS-BREW

EOF
exec zsh