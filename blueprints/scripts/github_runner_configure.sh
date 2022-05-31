#!/usr/bin/env bash


# Install Docker
sudo yum check-update
curl -fsSL https://get.docker.com/ | sh
sudo systemctl start docker
sudo systemctl enable docker
sudo usermod -aG docker $(whoami)

# Configure SSH for root user
echo "${SSH_PUBLIC_KEY}" | sudo tee -a /root/.ssh/authorized_keys > /dev/null 2>&1
