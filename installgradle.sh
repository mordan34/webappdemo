#!/bin/bash

cd ~/
wget -O ~/gradle-4.7-bin.zip https://services.gradle.org/distributions/gradle-4.7-bin.zip
sudo apt-get -y install unzip java-1.8.0-openjdk
sudo mkdir /opt/gradle
sudo unzip -d /opt/gradle/ ~/gradle-4.7-bin.zip
sudo echo 'export PATH=$PATH:/opt/gradle/gradle-4.7/bin' > gradle.sh
sudo mv gradle.sh /etc/profile.d/
sudo chmod 755 /etc/profile.d/gradle.sh
