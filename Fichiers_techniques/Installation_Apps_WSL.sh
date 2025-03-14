#!/bin/bash
echo
sudo
sudo apt update
sudo apt -y upgrade
sudo apt -y install whois
sudo apt -y install whatweb
sudo apt -y install python3-pip
sudo pip3 install holehe
sudo pip3 install ignorant
cd $HOME
git clone https://github.com/sherlock-project/sherlock.git
cd sherlock
sudo python3 -m pip install -r requirements.txt
echo 'alias sherlock="python3 $HOME/sherlock/sherlock/sherlock.py"' >> ~/.bashrc
cd $HOME
git clone https://github.com/LPETN2023/Telepathy_VM
cd Telepathy_VM
sudo python3 -m pip install -r requirements.txt
echo 'alias telepathy="python3 $HOME/Telepathy_VM/Telegram_ESP.py"' >> ~/.bashrc