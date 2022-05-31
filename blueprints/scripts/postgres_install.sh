#!/usr/bin/env bash


set -e

sudo yum install -y https://download.postgresql.org/pub/repos/yum/reporpms/EL-7-x86_64/pgdg-redhat-repo-latest.noarch.rpm
sudo yum install -y postgresql12 postgresql12-server
sudo /usr/pgsql-12/bin/postgresql-12-setup initdb

sudo systemctl start postgresql-12
sudo systemctl enable postgresql-12

sudo -u postgres psql -c  "ALTER USER postgres PASSWORD '${POSTGRES_PASSWORD}';"

sudo yum install -y patch
sudo patch /var/lib/pgsql/12/data/pg_hba.conf << EOF
--- pg_hba.org  2022-04-14 11:53:34.631851852 +0000
+++ pg_hba.conf 2022-03-16 14:16:17.944933197 +0000
@@ -83,7 +83,7 @@
 # "local" is for Unix domain socket connections only
 local   all             all                                     peer
 # IPv4 local connections:
-host    all             all             127.0.0.1/32            ident
+host    all             all             127.0.0.1/32            md5
 # IPv6 local connections:
 host    all             all             ::1/128                 ident
 # Allow replication connections from localhost, by a user with the
EOF

sudo systemctl restart postgresql-12