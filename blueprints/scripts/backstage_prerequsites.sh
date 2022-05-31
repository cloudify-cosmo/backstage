#!/usr/bin/env bash


sudo mkdir -p ${INSTALL_DIR}
sudo chown ${USER}:${USER} ${INSTALL_DIR}

curl -sL https://rpm.nodesource.com/setup_16.x | sudo bash -

sudo yum install -y nodejs
sudo npm install --global yarn
sudo yum install -y yum-utils
sudo yum-config-manager \
  --add-repo \
  https://download.docker.com/linux/centos/docker-ce.repo
sudo yum install -y docker-ce docker-ce-cli containerd.io
sudo systemctl start docker
sudo usermod -aG docker ${USER}

sudo yum install -y git
sudo yum install -y python3
sudo yum install -y centos-release-scl
sudo yum install -y llvm-toolset-7.0
sudo yum install -y llvm-toolset-7.0-cmake
sudo yum install -y devtoolset-8

cd ${INSTALL_DIR}
git clone https://github.com/backstage/backstage.git .
git checkout v1.0.3
