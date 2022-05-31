#!/usr/bin/env bash


set -e

ctx download_resource config/app-config.yaml ${INSTALL_DIR}/app-config.yaml

sed "s,http://localhost,http://${HOST},g" -i ${INSTALL_DIR}/app-config.yaml
sed "s,\${HOST},${HOST},g" -i ${INSTALL_DIR}/app-config.yaml
sed "s,\${HOST_PUBLIC},${HOST_PUBLIC},g" -i ${INSTALL_DIR}/app-config.yaml
sed "s,\${POSTGRES_PASSWORD},${POSTGRES_PASSWORD},g" -i ${INSTALL_DIR}/app-config.yaml
sed "s,\${PORT},${PORT},g" -i ${INSTALL_DIR}/app-config.yaml
sed "s,\${GITHUB_TOKEN},${GITHUB_TOKEN},g" -i ${INSTALL_DIR}/app-config.yaml

placeholder_text="# Cloudify components placeholder 1"
github_location="- type: github-discovery\n      target: https://${BACKSTAGE_ENTITIES_REPO_URL%.*}/blob/main/*.yaml"
sed "s,${placeholder_text},${github_location},g" -i ${INSTALL_DIR}/app-config.yaml

sudo sh -c "cat <<EOF > /etc/systemd/system/backstagebackend.service
[Unit]
Description=Backstage backend

[Service]
WorkingDirectory=${INSTALL_DIR}/packages/backend
ExecStart=/usr/bin/yarn start
Environment=\"POSTGRES_PASSWORD=${POSTGRES_PASSWORD}\"
Environment=\"HOST=${HOST}\"

Restart=always

[Install]
WantedBy=multi-user.target
EOF"

sudo sh -c "cat <<EOF > /etc/systemd/system/backstagefrontend.service
[Unit]
Description=Backstage frontent

[Service]
WorkingDirectory=${INSTALL_DIR}
ExecStart=/usr/bin/yarn start
Environment=\"HOST=${HOST}\"
Environment=\"PORT=${PORT}\"
Environment=\"GITHUB_TOKEN=${GITHUB_TOKEN}\"

Restart=always

[Install]
WantedBy=multi-user.target
EOF"

cd ${INSTALL_DIR}
scl enable devtoolset-8 llvm-toolset-7.0 - > /dev/null 2>&1 << EOF
yarn add --cwd packages/backend @backstage/integration
yarn add --cwd packages/backend @backstage/plugin-catalog-backend-module-github
EOF

cat << EOF > $INSTALL_DIR/packages/backend/src/plugins/catalog.ts
import { CatalogBuilder } from '@backstage/plugin-catalog-backend';
import { ScaffolderEntitiesProcessor } from '@backstage/plugin-scaffolder-backend';
import { Router } from 'express';
import { PluginEnvironment } from '../types';
import {
  GithubDiscoveryProcessor,
  GithubOrgReaderProcessor,
} from '@backstage/plugin-catalog-backend-module-github';
import {
  ScmIntegrations,
  DefaultGithubCredentialsProvider
} from '@backstage/integration';

export default async function createPlugin(
  env: PluginEnvironment,
): Promise<Router> {
  const builder = await CatalogBuilder.create(env);
  const integrations = ScmIntegrations.fromConfig(env.config);
  const githubCredentialsProvider =
    DefaultGithubCredentialsProvider.fromIntegrations(integrations);
  builder.addProcessor(
    GithubDiscoveryProcessor.fromConfig(env.config, {
      logger: env.logger,
      githubCredentialsProvider,
    }),
    GithubOrgReaderProcessor.fromConfig(env.config, {
      logger: env.logger,
      githubCredentialsProvider,
    }),
  );
  builder.addProcessor(new ScaffolderEntitiesProcessor());
  const { processingEngine, router } = await builder.build();
  await processingEngine.start();
  return router;
}
EOF

sed -i "91i\import { CssBaseline, ThemeProvider } from '@material-ui/core';" ${INSTALL_DIR}/packages/app/src/App.tsx
sed -i "92i\import { darkTheme } from '@backstage/theme';" ${INSTALL_DIR}/packages/app/src/App.tsx
sed -i "128i\  themes: [" ${INSTALL_DIR}/packages/app/src/App.tsx
sed -i "129i\    { id: 'dark', title: 'Dark', variant: 'dark', Provider: ({ children }) => (" ${INSTALL_DIR}/packages/app/src/App.tsx
sed -i "130i\        <ThemeProvider theme={darkTheme}>" ${INSTALL_DIR}/packages/app/src/App.tsx
sed -i "131i\          <CssBaseline>{children}</CssBaseline>" ${INSTALL_DIR}/packages/app/src/App.tsx
sed -i "132i\        </ThemeProvider>" ${INSTALL_DIR}/packages/app/src/App.tsx
sed -i "133i\      ),}," ${INSTALL_DIR}/packages/app/src/App.tsx
sed -i "134i\  ]," ${INSTALL_DIR}/packages/app/src/App.tsx

sudo systemctl enable backstagebackend
sudo systemctl enable backstagefrontend
