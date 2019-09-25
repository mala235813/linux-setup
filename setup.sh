#!/bin/bash

# Read email
read -p "Enter your email: " email

echo Email is ${email}

ssh-keygen -t rsa -b 4096 -C "${email}"

echo "Public keys:"
find ~/.ssh -name '*.pub' | xargs cat
echo -e "Go to \e[4mhttps://github.com\e[0m and add a public key"
echo -e "Go to \e[4mhttps://gitlab.com\e[0m and add a public key"

read -p "Press enter to continue"


# Uninstall arch packages
yay -Rc --noconfirm - < ./package-lists/repo-remove

# Uninstall aur packages
yay -Rc --noconfirm - < ./package-lists/aur-remove

# Install arch packages
yay -S --noconfirm - < ./package-lists/repo-add

# Install aur packages
yay -S --noconfirm - < ./package-lists/aur-add

# Setup Spacemacs
rm -rf ~/.emacs.d
git clone https://github.com/syl20bnr/spacemacs ~/.emacs.d

