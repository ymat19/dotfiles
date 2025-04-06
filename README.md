[![CI/Test](https://github.com/ymat19/dotfiles/actions/workflows/test.yml/badge.svg)](https://github.com/ymat19/dotfiles/actions/workflows/test.yml)
[![CI/Update](https://github.com/ymat19/dotfiles/actions/workflows/flake-update.yml/badge.svg)](https://github.com/ymat19/dotfiles/actions/workflows/flake-update.yml)

### nix, home-manager setup

```
curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install --no-confirm
. /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh

nix-channel --add https://github.com/nix-community/home-manager/archive/master.tar.gz home-manager
nix-channel --update

nix-shell '<home-manager>' -A install
```

### apply

```
home-manager switch --flake .#ymat19 --impure -b backup
```

### etc

```
# enable clipboard on linux
sudo apt-get install xsel

# fix lazygit error on linux
sudo chmod a+rw /dev/tty

# add ghq base
git config --global --add ghq.root $(realpath ../)

# Make neovim symlink for wsl.exe (vscode neovim needs this)
sudo ln -s $(which nvim) /usr/local/bin/nvim

# allpy on NixOS
sudo nixos-rebuild switch -I nixos-config=configuration.nix

# nix-shell with pyenv dependencies
nix-shell -p zlib xz readline libffi libuuid openssl sqlite bzip2 tk

# rebuild asdf shims
asdf reshims
```

### docs

- https://home-manager-options.extranix.com/?query=&release=release-24.05
- https://search.nixos.org/packages?channel=24.11&from=0&size=50&sort=relevance&type=packages&query=vimPlugins
