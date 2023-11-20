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
sudo pip3 install telepathy
git clone https://github.com/sherlock-project/sherlock.git
cd sherlock
sudo python3 -m pip install -r requirements.txt
echo 'alias sherlock="python3 /home/ubuntu/sherlock/sherlock/sherlock.py"' >> ~/.bashrc