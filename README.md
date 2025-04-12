# Dotfiles

[![CI/Test](https://github.com/ymat19/dotfiles/actions/workflows/test.yml/badge.svg)](https://github.com/ymat19/dotfiles/actions/workflows/test.yml)
[![CI/Update](https://github.com/ymat19/dotfiles/actions/workflows/flake-update.yml/badge.svg)](https://github.com/ymat19/dotfiles/actions/workflows/flake-update.yml)

This repository contains my personal dotfiles managed with [Nix](https://nixos.org/) and [home-manager](https://github.com/nix-community/home-manager). It supports both standalone home-manager and NixOS setups, with special consideration for WSL environments.

## Features

- 📦 Nix-based configuration management
- 🔄 Automated setup with installation script
- 🐧 Support for both standalone home-manager and NixOS
- 🪟 WSL (Windows Subsystem for Linux) compatibility
- 🛠️ Pre-configured development tools:
  - Dual Neovim configurations (IDE-like and VSCode integration)
  - tmux
  - zsh
  - Git configuration
  - Various CLI utilities

## Directory Structure

- `configs/` - Tool-specific configurations
  - `kvim/` - Full-featured Neovim configuration (IDE-like setup)
  - `nvim/` - Minimal Neovim configuration (for VSCode integration)
  - Various dotfiles (.vimrc, tmux.conf, zshrc)
- `modules/` - Nix configuration modules
- `flake.nix` - Main Nix flake configuration
- `home.nix` - Home-manager configuration
- `install.sh` - Automated installation script

## Neovim Setup

This repository features two distinct Neovim configurations, managed through different `NVIM_APPNAME` environments:

### 1. Full IDE-like Setup (kvim)

Located in `configs/kvim/`, this is a feature-rich configuration based on [kickstart.nvim](https://github.com/nvim-lua/kickstart.nvim).

- **Usage**: `kvim` (aliased command)
- **Features**:
  - LSP integration with `nvim-lspconfig`
  - Syntax highlighting via `nvim-treesitter`
  - Modern UI with `tokyonight-nvim` theme
  - Enhanced movement with `quick-scope`, `clever-f-vim`, and `leap-nvim`
  - Text manipulation tools: `substitute-nvim`, `nvim-surround`, `dial-nvim`
  - GitHub Copilot integration with chat support
  - Additional tools: Mermaid diagram support, Nix language server

### 2. VSCode Integration Setup (nvim)

Located in `configs/nvim/`, this is a minimal configuration designed specifically for use with the VSCode Neovim extension.

- **Usage**: Regular `nvim` command when using VSCode
- **Features**:
  - Enhanced movement with `quick-scope`, `clever-f-vim`, and `leap-nvim`
  - Text manipulation: `substitute-nvim`, `nvim-surround`, `dial-nvim`
  - LSP and treesitter support (`nvim-lspconfig`, `nvim-treesitter`)
  - Core settings: case-insensitive search, soft tabs, clipboard integration
- **Purpose**: Enhances VSCode's Vim emulation while maintaining compatibility

## Installation

### Quick Start

Run the automated installation script:

```bash
./install.sh
```

This script will:

1. Remove any existing Nix installation
2. Install Nix using the Determinate Systems installer
3. Set up home-manager
4. Apply the configuration

### Manual Setup

#### Standalone Home-manager Setup

1. Install Nix:

```bash
curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install --no-confirm
. /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
```

2. Set up home-manager:

```bash
nix-channel --add https://github.com/nix-community/home-manager/archive/master.tar.gz home-manager
nix-channel --update
nix-shell '<home-manager>' -A install
```

3. Apply configuration:

```bash
home-manager switch --flake . --impure -b backup
```

#### NixOS Setup

1. Back up and link configuration:

```bash
cp /etc/nixos/hardware-configuration.nix ./
sudo mv /etc/nixos /etc/nixos.bak
sudo ln -s $(realpath $(pwd)) /etc/nixos
```

2. Apply configuration:

```bash
sudo nixos-rebuild switch --impure
```

## Additional Setup Steps

### WSL-specific Setup

```bash
# Make neovim symlink for WSL (required for VSCode Neovim)
sudo ln -s $(which nvim) /usr/local/bin/nvim
```

### General Utilities

```bash
# Enable clipboard on Linux
sudo apt-get install xsel

# Fix lazygit error on Linux
sudo chmod a+rw /dev/tty

# Configure ghq base directory
git config --global --add ghq.root $(realpath ../)

# Rebuild asdf shims if needed
asdf reshims

# create gitconfig
touch ~/.gitconfig
```

## Useful Documentation

- [Home Manager Options Search](https://home-manager-options.extranix.com/?query=&release=release-24.05)
- [Nixpkgs Packages Search](https://search.nixos.org/packages?channel=24.11&from=0&size=50&sort=relevance&type=packages&query=vimPlugins)

## License

See [LICENSE.md](LICENSE.md) for details.
