#!/bin/sh

git add .
git commit -m "$(date)"

nixos-rebuild $1 --flake /srv/shares/Users/Silverdev2482/Router-Server/
