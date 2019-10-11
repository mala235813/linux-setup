#!/bin/bash
# Uninstall packages
yay -Rc --noconfirm chromium

# Install packages
yay -S --noconfirm make

# Install packages
yay -S --noconfirm clojure
yay -S --noconfirm drive-bin
yay -S --noconfirm firefox
yay -S --noconfirm kdiff3-qt
yay -S --noconfirm overgrive
yay -S --noconfirm xclip

# Setup Spacemacs
yay -S --noconfirm emacs
yay -S --noconfirm ttf-unifont
rm -rf ~/.emacs.d
git clone https://github.com/syl20bnr/spacemacs ~/.emacs.d

# Setup ssh keys
read -p "Enter your email: " email

echo Email is ${email}

ssh-keygen -t rsa -b 4096 -C "${email}"

echo "Public keys:"
find ~/.ssh -name '*.pub' | xargs cat
echo -e "Go to \e[4mhttps://github.com\e[0m and add a public key"
echo -e "Go to \e[4mhttps://gitlab.com\e[0m and add a public key"

