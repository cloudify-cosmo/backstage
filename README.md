# backstage
backstage.io installation info

## Backstage POC deployment requirements
### Secrets
Before deploying the Backstage POC setup from [backstage](./blueprints/backstage.yaml)
blueprint, setup the following secrets in your Cloudify Manager:

 - _LICENSE_ - with the contents of a valid Cloudify license used for Cloudify Manager
 - _aws_access_key_id_ - Access Key ID of your AWS account
 - _aws_secret_access_key_ - Secret Access Key of your AWS account
 - _github_token_ - GitHub Token generated for your GitHub user
 - _github_username_ - your GitHub account user name
 - _postgres_password_ - password that will be used for PostgreSQL database

Additionally, the following secrets will be created during the deployment lifecycle:

 - _backstage_vm_ssh_key_private_
 - _backstage_vm_ssh_key_public_
 - _cloudify_manager_vm_ssh_key_private_
 - _cloudify_manager_vm_ssh_key_public_
 - _github_runner_vm_ssh_key_private_
 - _github_runner_vm_ssh_key_public_

Those secrets names can be changed in the [backstage](./blueprints/backstage.yaml) blueprint.

### Plugins
Upload following [plugins](https://cloudify.co/plugins/) to your Cloudify Manager:

 - cloudify-aws-plugin
 - cloudify-fabric-plugin
 - cloudify-utilities-plugin

## VM requirements
CPUs ?

RAM 8GB

Storage ?

## Install prerequisites

Installation instructions https://backstage.io/docs/getting-started/running-backstage-locally

### Go to dir for backstage installation
```
cd
```

### NodeJS LTS
```
curl -sL https://rpm.nodesource.com/setup_16.x | sudo bash -

sudo yum install -y nodejs
```

### yarn
```
sudo npm install --global yarn
```

### Docker
```
sudo yum install -y yum-utils
sudo yum-config-manager \
  --add-repo \
  https://download.docker.com/linux/centos/docker-ce.repo
sudo yum install -y docker-ce docker-ce-cli containerd.io
sudo systemctl start docker

sudo usermod -aG docker $USER
```

### git
```
sudo yum install -y git
```

### Python3 
```
sudo yum install -y python3
```


### SCL (needed for new g++)
```
sudo yum install -y centos-release-scl
sudo yum install -y llvm-toolset-7.0
sudo yum install -y llvm-toolset-7.0-cmake
sudo yum install -y devtoolset-8

scl enable devtoolset-8 bash
scl enable llvm-toolset-7.0 bash
```

## Install from npm (interactive)
```
npx @backstage/create-app
cd my-backstage-app
yarn dev
```

## Install for dev

## Clone and build
```
git clone https://github.com/backstage/backstage.git
cd backstage
git checkout v1.0.3
```

### Node options
#### Needed for yarn tsc
```
export NODE_OPTIONS=--max_old_space_size=4096
```
#### Install and setup service
```
yarn install
yarn tsc
yarn build


IP=$(hostname -I | awk '{print $1}') sh -c 'sed "s,baseUrl: http://localhost:3000,baseUrl: http://${IP}:3000,g" -i app-config.yaml'

sudo sh -c 'cat <<EOF > /etc/systemd/system/backstagebackend.service
[Unit]
Description=Backstage backend

[Service]
WorkingDirectory=${PWD}/packages/backend
ExecStart=/usr/bin/yarn start

Restart=always

[Install]
WantedBy=multi-user.target
EOF'

sudo sh -c 'cat <<EOF > /etc/systemd/system/backstagefrontend.service
[Unit]
Description=Backstage frontent

[Service]
WorkingDirectory=${PWD}
ExecStart=/usr/bin/yarn start

Restart=always

[Install]
WantedBy=multi-user.target
EOF'

sudo systemctl enable backstagebackend
sudo systemctl enable backstagefrontend
sudo systemctl start backstagebackend
sudo systemctl start backstagefrontend
```

## Optional components
### Postgresql
```
sudo yum install -y https://download.postgresql.org/pub/repos/yum/reporpms/EL-7-x86_64/pgdg-redhat-repo-latest.noarch.rpm
sudo yum install -y postgresql12 postgresql12-server
sudo /usr/pgsql-12/bin/postgresql-12-setup initdb

sudo systemctl start postgresql-12
sudo systemctl enable postgresql-12
```
### Postgres config
```
sudo -u postgres psql -c  "ALTER USER postgres PASSWORD 'secret';"
```
### Backstage psql config
```
cd packages/backend
yarn add pg
```
Adjust config: https://backstage.io/docs/getting-started/configuration

### update postgres conf
in file /var/lib/pgsql/12/data/pg_hba.conf
change
host    all             all             127.0.0.1/32            idnet
to
host    all             all             127.0.0.1/32            md5

```
sudo systemctl restart postgresql-12
```
