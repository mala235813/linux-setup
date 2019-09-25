#!/bin/bash

# Uninstall arch packages
yay -Rc --noconfirm - < ./package-lists/repo-remove

# Uninstall aur packages
yay -Rc --noconfirm - < ./package-lists/aur-remove

# Install arch packages
yay -S --noconfirm - < ./package-lists/repo-add

# Install aur packages
yay -S --noconfirm - < ./package-lists/aur-add
