# Homebrew - Rootless

[![GitHub release](https://img.shields.io/github/release/Homebrew/brew.svg)](https://github.com/mietzen/brew-rootless/tags)

This is a fork of [Homebrew - Brew](https://github.com/homebrew/brew), but it has one important change:

https://github.com/mietzen/brew-rootless/blob/2df9a6b29baa6421ebc3f56b8361fad853672542/Library/Homebrew/cask/artifact/abstract_uninstall.rb#L93

On uninstalling cask it won't try to use `sudo` to uninstall `launchctl` services. 

This is important when installing brew without root permissions.

This fork is synced including tags, so it should allways be up to date.
