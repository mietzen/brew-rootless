# Homebrew - Rootless

[![GitHub release](https://img.shields.io/github/release/Homebrew/brew.svg)](https://github.com/mietzen/brew-rootless/tags)

Welcome to **Homebrew - Rootless**, a fork of [Homebrew](https://github.com/homebrew/brew) tailored for users without root permissions on their mac. 

### Caveats:

Using `brew` in a rootless setup has some caveats: Most formulae will be built from source, and some casks and formulae may not be available. If you'd like to know why, read [this](https://docs.brew.sh/Installation#untar-anywhere-unsupported).

### Features:
- **Rootless**: Brew can be installed and managed without root access.
- **Cask installations**: Default to `~/Applications` for user-level convenience.
- **Cask uninstallation**: Won't prompt for your password when removing `launchctl` services.
- **Up-to-date**: This fork is continuously synced with the main repository, including tags, to stay up-to-date with the latest changes.

## Supported Platforms:
- MacOS ARM64 (M1)

## Install

**Automatic**

```shell
curl -s https://raw.githubusercontent.com/mietzen/brew-rootless/refs/heads/master/install.sh | zsh
```

**Manual**

```shell
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
```

## Uninstall

```shell
sed -i '/### ROOTLESS-BREW/,/### ROOTLESS-BREW/d' $HOME/.zshrc
rm -rf $HOME/.local/opt/homebrew
```

## Issues:
Please **do not open issues** on the [Homebrew main repository](https://github.com/homebrew/brew) for any problems encountered using this fork. Issues specific to the rootless version should be raised [**here**](https://github.com/mietzen/porkbun-ddns/issues/new/choose) instead.


## Special Thanks:
We deeply appreciate the tremendous work done by the [Homebrew team](https://github.com/homebrew). Their effort is what makes this project possible, and we stand on their shoulders to bring this rootless-friendly fork to life.

## Disclaimer:
I am not responsible for the content of formulae and casks available in this fork. All trademarks, logos, and brand names are the property of their respective owners. All company, product, and service names used in this software are for identification purposes only. The use of these names, trademarks, and brands does not imply endorsement.
