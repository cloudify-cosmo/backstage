#!/usr/bin/env bash


# Script takes the following inputs:
# - LICENSE - valid license for the Cloudify Manager
# - PRIVATE_IP - private IP of the host VM
# - PUBLIC_IP - public IP of the host VM
# - ADMIN_PASSWORD - password to set for the Cloudify Manager's admin user

CM_RPM_URL='https://repository.cloudifysource.org/cloudify/6.3.1/ga-release/cloudify-manager-install-6.3.1-ga.el7.x86_64.rpm'
RPM_NAME='cloudify-manager-install-6.3.1-ga.el7.x86_64.rpm'


curl ${CM_RPM_URL} -o ${RPM_NAME}
sudo yum install -y ${RPM_NAME}
sudo yum install -y openssl

echo "${LICENSE}" > /tmp/license.yaml
sudo sed -i "s/cloudify_license_path: ''/cloudify_license_path: \/tmp\/license.yaml/" /etc/cloudify/config.yaml
sudo sed -i "s/ssl_enabled: true/ssl_enabled: false/" /etc/cloudify/config.yaml

sudo cfy_manager install \
    --private-ip "${PRIVATE_IP}" \
    --public-ip "${PUBLIC_IP}" \
    --admin-password "${ADMIN_PASSWORD}"

rm -f /tmp/license.yaml
