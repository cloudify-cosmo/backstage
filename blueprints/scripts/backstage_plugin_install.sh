#!/usr/bin/env bash


set -e
AUTHENTICATION_BASE64=`echo -n "admin:${ADMIN_PASSWORD}" | base64`
ctx download_resource resources/backstage-cloudify-plugin.zip ~/backstage-cloudify-plugin.zip

cd ${INSTALL_DIR}
yarn create-plugin --option id=cloudify --option owner=''

rm -rf ${INSTALL_DIR}/plugins/cloudify/*
unzip ~/backstage-cloudify-plugin.zip -d ${INSTALL_DIR}/plugins/cloudify
rm -f ~/backstage-cloudify-plugin.zip

sed "s+\${CLOUDIFY_MANAGER_IP}+${CLOUDIFY_MANAGER_IP}+g" -i ${INSTALL_DIR}/plugins/cloudify/src/components/BlueprintsComponent/BlueprintsComponent.tsx
sed "s+\${BACKSTAGE_BACKEND_IP}+${BACKSTAGE_BACKEND_IP}+g" -i ${INSTALL_DIR}/plugins/cloudify/src/components/BlueprintsComponent/BlueprintsComponent.tsx

sed "s+\${CLOUDIFY_MANAGER_IP}+${CLOUDIFY_MANAGER_IP}+g" -i ${INSTALL_DIR}/plugins/cloudify/src/components/DeploymentsComponent/DeploymentsComponent.tsx
sed "s+\${BACKSTAGE_BACKEND_IP}+${BACKSTAGE_BACKEND_IP}+g" -i ${INSTALL_DIR}/plugins/cloudify/src/components/DeploymentsComponent/DeploymentsComponent.tsx

sed "s+.addRouter('', await app(appEnv));+.addRouter('', await app(appEnv))+g" -i ${INSTALL_DIR}/packages/backend/src/index.ts
sed -i "163i\    .addRouter('/proxy', await proxy(proxyEnv));" ${INSTALL_DIR}/packages/backend/src/index.ts

sed -i "55i\  '/cloudify/api':" ${INSTALL_DIR}/app-config.yaml
sed -i "56i\    target: http://${CLOUDIFY_MANAGER_IP}/api/v3.1" ${INSTALL_DIR}/app-config.yaml
sed -i "57i\    headers:" ${INSTALL_DIR}/app-config.yaml
sed -i "58i\      Authorization: Basic ${AUTHENTICATION_BASE64}" ${INSTALL_DIR}/app-config.yaml
sed -i "59i\      Tenant: default_tenant\n" ${INSTALL_DIR}/app-config.yaml

sed -i "29i\import CloudIcon from '@material-ui/icons/Cloud';" ${INSTALL_DIR}/packages/app/src/components/Root/Root.tsx
sed -i "103i\          <SidebarItem icon={CloudIcon} to=\"cloudify\" text=\"Cloudify\" />" ${INSTALL_DIR}/packages/app/src/components/Root/Root.tsx
