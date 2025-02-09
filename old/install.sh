#!/bin/bash

# 各種スクリプトを呼び出す
apt-get update && apt-get install -y zsh
chsh -s $(which zsh)
./setupApps.sh
./makeSymLn.sh

