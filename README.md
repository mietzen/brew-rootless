# Homebrew - Rootless

[![GitHub release](https://img.shields.io/github/release/Homebrew/brew.svg)](https://github.com/mietzen/brew-rootless/tags)

Welcome to **Homebrew - Rootless**, a fork of [Homebrew](https://github.com/homebrew/brew) tailored for users without root permissions on their mac. This version is optimized for rootless installations, with a primary modification to the cask uninstallation process:

https://github.com/mietzen/brew-rootless/blob/2df9a6b29baa6421ebc3f56b8361fad853672542/Library/Homebrew/cask/artifact/abstract_uninstall.rb#L93

 Cask uninstallation won't prompt for your password when removing `launchctl` services.

## Key Features:
- **Rootless Optimizations**: Brew can be installed and managed without root access.
- **Cask installations** default to `~/Applications` for user-level convenience.
- **Source-based Formulae**: Most formulae will built from source, with some limitations in availability compared to the standard version.
- **Up-to-date**: This fork is continuously synced with the main repository, including tags, to stay up-to-date with the latest changes.

## Issues:
Please **do not open issues** on the [Homebrew main repository](https://github.com/homebrew/brew) for any problems encountered using this fork. Issues specific to the rootless version should be raised [**here**](https://github.com/mietzen/porkbun-ddns/issues/new/choose) instead.


## Special Thanks:
We deeply appreciate the tremendous work done by the [Homebrew team](https://github.com/homebrew). Their effort is what makes this project possible, and we stand on their shoulders to bring this rootless-friendly fork to life.

## Disclaimer:
I am not responsible for the content of formulae and casks available in this fork. All trademarks, logos, and brand names are the property of their respective owners. All company, product, and service names used in this software are for identification purposes only. The use of these names, trademarks, and brands does not imply endorsement.
