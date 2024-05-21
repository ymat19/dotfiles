#!/bin/bash

# 各種スクリプトを呼び出す
apt-get install -y zsh
./setupApps.sh
./makeSymLn.sh

