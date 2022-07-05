#!/usr/bin/env bash


set -e

ctx download_resource config/app-config.yaml ${INSTALL_DIR}/app-config.yaml

sed "s,http://localhost,http://${HOST},g" -i ${INSTALL_DIR}/app-config.yaml
sed "s,\${HOST},${HOST},g" -i ${INSTALL_DIR}/app-config.yaml
sed "s,\${HOST_PUBLIC},${HOST_PUBLIC},g" -i ${INSTALL_DIR}/app-config.yaml
sed "s,\${POSTGRES_PASSWORD},${POSTGRES_PASSWORD},g" -i ${INSTALL_DIR}/app-config.yaml
sed "s,\${PORT},${PORT},g" -i ${INSTALL_DIR}/app-config.yaml
sed "s,\${GITHUB_TOKEN},${GITHUB_TOKEN},g" -i ${INSTALL_DIR}/app-config.yaml
sed "s,computeEngine:,Dev_Deployments:,g" -i ${INSTALL_DIR}/app-config.yaml
sed "s,Compute Engine,DEV Deployments,g" -i ${INSTALL_DIR}/app-config.yaml
sed "s,cloudDataflow:,Prod_Deployments:,g" -i ${INSTALL_DIR}/app-config.yaml
sed "s,Cloud Dataflow,PROD Deployments,g" -i ${INSTALL_DIR}/app-config.yaml
sed "s,cloudStorage:,Projects:,g" -i ${INSTALL_DIR}/app-config.yaml
sed "s,Cloud Storage,Projects,g" -i ${INSTALL_DIR}/app-config.yaml
sed '/    bigQuery:/,+5d' -i /opt/backstage/app-config.yaml

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

cat << EOF > $INSTALL_DIR/packages/app/src/CostInsightsClient.ts
import {
  Alert,
  Cost,
  CostInsightsApi,
  DEFAULT_DATE_FORMAT,
  Entity,
  Group,
  MetricData,
  ProductInsightsOptions,
  Project,
} from "@backstage/plugin-cost-insights";
import {
  aggregationFor,
  changeOf,
  trendlineOf,
} from "@backstage/plugin-cost-insights/src/testUtils";
import {
  CostExplorerClient,
  GetCostAndUsageCommand,
} from "@aws-sdk/client-cost-explorer";
import { Interval } from "repeating-interval";
import { DateTime } from "luxon";
import {
  Duration,
  ProjectGrowthData,
} from "@backstage/plugin-cost-insights/src/types";
import { ProjectGrowthAlert } from "@backstage/plugin-cost-insights/src/alerts";
import {
  inclusiveEndDateOf,
  inclusiveStartDateOf,
} from "@backstage/plugin-cost-insights/src/utils/duration";

export class CostInsightsClient implements CostInsightsApi {
  growth_alert_threshold = 0.01;
  tag_key = "cloudify-deployment";
  default_tag_val = "Other";

  async getCredentials(project: string): Object {
    const dev = {
      accessKeyId: "AKIAQFF54CGJROMFZA7P",
      secretAccessKey: "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",
    };
    const prod = {
      accessKeyId: "AKIA446YSIAJ6WFNLB4V",
      secretAccessKey: "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",
    };

    switch (project) {
      case "dev": {
        return dev;
      }
      case "prod": {
        return prod;
      }
      default: {
        return dev;
      }
    }
  }

  async getAwsCostAndUsage(
    project: string,
    start: string,
    end: string,
    filter: Object = {}
  ): Object {
    const client = new CostExplorerClient({
      region: "us-east-1",
      credentials: this.getCredentials(project),
    });
    const input = {
      TimePeriod: {
        Start: start,
        End: end,
      },
      Metrics: ["UNBLENDED_COST"],
      Granularity: "DAILY",
    };
    const filter_input = {
      ...input,
      ...filter,
    };

    const command = new GetCostAndUsageCommand(filter_input);
    const data = await client.send(command);
    return data;
  }

  async getLastCompleteBillingDate(): Promise<string> {
    return Promise.resolve(
      DateTime.now().minus({ days: 1 }).toFormat(DEFAULT_DATE_FORMAT)
    );
  }

  async getUserGroups(userId: string): Promise<Group[]> {
    return [{ id: "Cloudify" }];
  }

  async getGroupProjects(group: string): Promise<Project[]> {
    return [{ id: "dev" }, { id: "prod" }];
  }

  async getAlerts(group: string): Promise<Alert[]> {
    const alerts: Alert[] = [];
    const lastCompleteBillingDate = await this.getLastCompleteBillingDate();

    // Last quarter start and end dates
    const iso_end: string = inclusiveEndDateOf(
      Duration.P3M,
      lastCompleteBillingDate
    );
    const last_q: string = DateTime.fromISO(iso_end).toFormat("yyyy-'Q'q");
    const last_q_start: string = DateTime.fromISO(iso_end)
      .startOf("quarter")
      .toFormat("yyyy-MM-dd");
    const last_q_end: string = DateTime.fromISO(iso_end).toFormat("yyyy-MM-dd");

    // First quarter start and end dates
    const iso_start: string = inclusiveStartDateOf(
      Duration.P3M,
      lastCompleteBillingDate
    );
    const first_q: string = DateTime.fromISO(iso_start).toFormat("yyyy-'Q'q");
    const first_q_start: string =
      DateTime.fromISO(iso_start).toFormat("yyyy-MM-dd");
    const first_q_end: string = DateTime.fromISO(iso_start)
      .endOf("quarter")
      .toFormat("yyyy-MM-dd");

    const group_projects = await this.getGroupProjects(group);
    for (const project of group_projects) {
      const last_data = await this.getAwsCostAndUsage(
        project["id"],
        last_q_start,
        last_q_end
      );
      const first_data = await this.getAwsCostAndUsage(
        project["id"],
        first_q_start,
        first_q_end
      );

      // As not given month, but last X days are needed,
      // here costs are extracted and summed.
      let last_costs = [];
      last_data.ResultsByTime?.map((value) => {
        last_costs = [
          ...last_costs,
          parseFloat(value.Total?.UnblendedCost.Amount),
        ];
      });

      let first_costs = [];
      first_data.ResultsByTime?.map((value) => {
        first_costs = [
          ...first_costs,
          parseFloat(value.Total?.UnblendedCost.Amount),
        ];
      });

      const aggregation = [
        first_costs.reduce((a, b) => a + b, 0),
        last_costs.reduce((a, b) => a + b, 0),
      ];

      const change = changeOf([
        { amount: aggregation[0] },
        { amount: aggregation[1] },
      ]);

      if (change.amount > this.growth_alert_threshold) {
        const last_costs = new Map<string, Array<number>>();
        const first_costs = new Map<string, Array<number>>();

        const group_input = {
          GroupBy: [
            {
              Type: "DIMENSION",
              Key: "SERVICE",
            },
          ],
        };

        const last_data = await this.getAwsCostAndUsage(
          project["id"],
          last_q_start,
          last_q_end,
          group_input
        );
        const first_data = await this.getAwsCostAndUsage(
          project["id"],
          first_q_start,
          first_q_end,
          group_input
        );

        // As not given month, but last X days are needed,
        // here costs are extracted and summed.
        last_data.ResultsByTime?.map((value) => {
          if (value.Groups.length > 0) {
            value.Groups.forEach((item) => {
              const key = item.Keys[0];
              const val = parseFloat(item.Metrics.UnblendedCost.Amount);
              const collection = last_costs.get(key);
              if (!collection) {
                last_costs.set(key, [val]);
              } else {
                collection.push(val);
              }
            });
          } else {
            const val = parseFloat(value.Total?.UnblendedCost.Amount);
            const collection = last_costs.get(this.default_tag_val);
            if (!collection) {
              last_costs.set(this.default_tag_val, [val]);
            } else {
              collection.push(val);
            }
          }
        });
        first_data.ResultsByTime?.map((value) => {
          if (value.Groups.length > 0) {
            value.Groups.forEach((item) => {
              const key = item.Keys[0];
              const val = parseFloat(item.Metrics.UnblendedCost.Amount);
              const collection = first_costs.get(key);
              if (!collection) {
                first_costs.set(key, [val]);
              } else {
                collection.push(val);
              }
            });
          } else {
            const val = parseFloat(value.Total?.UnblendedCost.Amount);
            const collection = first_costs.get(this.default_tag_val);
            if (!collection) {
              first_costs.set(this.default_tag_val, [val]);
            } else {
              collection.push(val);
            }
          }
        });

        const aggregation_map = new Map<string, number[]>();
        last_costs.forEach((val, key) => {
          aggregation_map.set(key, [0, val.reduce((a, b) => a + b, 0)]);
        });
        first_costs.forEach((val, key) => {
          const collection = aggregation_map.get(key);
          if (!collection) {
            // the tag didn't exist in last X days
            aggregation_map.set(key, [val.reduce((a, b) => a + b, 0), 0]);
          } else {
            // the tag did exist
            collection[0] += val.reduce((a, b) => a + b, 0);
          }
        });

        // We expect to AWS won't return cost unassigned to any service
        if (
          aggregation_map.get(this.default_tag_val)[0] === 0 &&
          aggregation_map.get(this.default_tag_val)[1] === 0
        ) {
          aggregation_map.delete(this.default_tag_val);
        }

        const projectGrowthData: ProjectGrowthData = {
          project: project["id"],
          periodStart: first_q,
          periodEnd: last_q,
          aggregation: aggregation,
          change: change,
          products: Array.from(aggregation_map, ([key, value]) => ({
            id: key,
            aggregation: value,
          })),
        };
        alerts.push(new ProjectGrowthAlert(projectGrowthData));
      }
    }

    return alerts;
  }

  async getDailyMetricData(
    metric: string,
    intervals: string
  ): Promise<MetricData> {
    // Generate random data
    const aggregation = aggregationFor(intervals, 100_000).map((entry) => ({
      ...entry,
      amount: Math.round(entry.amount),
    }));

    const data = {
      format: "number",
      aggregation: aggregation,
      change: changeOf(aggregation),
      trendline: trendlineOf(aggregation),
    };

    return data;
  }

  async getGroupDailyCost(group: string, intervals: string): Promise<Cost> {
    const cost: Cost = {
      id: group,
      format: "number",
      aggregation: [],
      change: {
        ratio: 0,
        amount: 0,
      },
      trendline: {},
    };

    // Calculate start date from iso8601 format
    const moment = require("moment");
    const rep_interval = new Interval(intervals);
    let start = moment(rep_interval._end).clone();
    for (let _i = 0; _i < rep_interval.repetitions; _i++) {
      start = start.subtract(rep_interval.duration);
    }

    const group_projects = await this.getGroupProjects(group);
    for (const project of group_projects) {
      const data = await this.getAwsCostAndUsage(
        project["id"],
        start.format("YYYY-MM-DD"),
        moment(rep_interval._end).format("YYYY-MM-DD")
      );

      // Append to costs aggregation
      data.ResultsByTime?.map((value) => {
        cost.aggregation = [
          ...cost.aggregation,
          {
            amount: parseFloat(value.Total?.UnblendedCost.Amount),
            date: value.TimePeriod?.Start,
          },
        ];
      });
    }

    // Group by dates in aggregation array head
    const days = cost.aggregation.length / group_projects.length;
    for (let i = 1; i < group_projects.length; i++) {
      for (let j = 0; j < days; j++) {
        if (cost.aggregation[j].date !== cost.aggregation[j + i * days].date) {
          console.warn(
            "Cannot aggregate inconsistent data between projects: " +
              cost.aggregation[j].date +
              " is not equal to " +
              cost.aggregation[j + i * days].date +
              ". Results may be invalid."
          );
        }
        cost.aggregation[j].amount += cost.aggregation[j + i * days].amount;
      }
    }
    // Cut aggregation tail
    cost.aggregation = cost.aggregation.slice(0, days);

    // Calculate change and trendline
    cost.change = changeOf(cost.aggregation);
    cost.trendline = trendlineOf(cost.aggregation);

    return cost;
  }

  async getProjectDailyCost(project: string, intervals: string): Promise<Cost> {
    const cost: Cost = {
      id: project,
      format: "number",
      aggregation: [],
      change: {
        ratio: 0,
        amount: 0,
      },
      trendline: {},
    };

    // Calculate start date from iso8601 format
    const moment = require("moment");
    const rep_interval = new Interval(intervals);
    let start = moment(rep_interval._end).clone();
    for (let _i = 0; _i < rep_interval.repetitions; _i++) {
      start = start.subtract(rep_interval.duration);
    }

    const data = await this.getAwsCostAndUsage(
      project,
      start.format("YYYY-MM-DD"),
      moment(rep_interval._end).format("YYYY-MM-DD")
    );

    // Prepare and return valid Cost object
    data.ResultsByTime?.map((value) => {
      cost.aggregation = [
        ...cost.aggregation,
        {
          amount: parseFloat(value.Total?.UnblendedCost.Amount),
          date: value.TimePeriod?.Start,
        },
      ];
    });
    cost.change = changeOf(cost.aggregation);
    cost.trendline = trendlineOf(cost.aggregation);

    return cost;
  }

  async getProductInsights(options: ProductInsightsOptions): Promise<Entity> {
    const entity: Entity = {
      id: options.product,
      aggregation: [0, 0],
      change: {
        ratio: 0,
        amount: 0,
      },
      entities: {
        services: [],
      },
    };

    const last_costs = new Map();
    const first_costs = new Map();

    // Calculate start date from iso8601 format
    const moment = require("moment");
    const rep_interval = new Interval(options.intervals);
    let start = moment(rep_interval._end).clone();
    for (let _i = 0; _i < rep_interval.repetitions; _i++) {
      start = start.subtract(rep_interval.duration);
    }

    // Prepare dates and filter input for AWS API calls
    const last_half_start: string = moment(rep_interval._end)
      .subtract(rep_interval.duration)
      .format("YYYY-MM-DD");
    const last_half_end: string = moment(rep_interval._end).format(
      "YYYY-MM-DD"
    );
    const first_half_start: string = start.format("YYYY-MM-DD");
    const first_half_end: string = start
      .add(rep_interval.duration)
      .format("YYYY-MM-DD");

    const filter_input = {};

    // 'Deployments' and 'Projects' as product names behaves a bit different
    // - '<Project ID>_Deployments' displays all deployment tags in project
    // - 'Projects' displays total costs grouped by Project ID
    if (options.product.toLowerCase() !== "projects") {
      filter_input.GroupBy = [
        {
          Type: "TAG",
          Key: this.tag_key,
        },
      ];
    }

    if (
      options.product.toLowerCase().indexOf("deployments") === -1 && // not found in product
      options.product.toLowerCase() !== "projects"
    ) {
      filter_input.Filter = {
        Dimensions: {
          Key: "SERVICE",
          Values: [
            options.product.replaceAll("_X_", " - ").replaceAll("_", " "),
          ],
        },
      };
    }
    let group_projects = [];
    if (options.product.toLowerCase().endsWith("deployments")) {
      group_projects = [{ id: options.product.split("_")[0].toLowerCase() }];
    } else {
      group_projects = await this.getGroupProjects(options.group);
    }
    for (const project of group_projects) {
      const last_data = await this.getAwsCostAndUsage(
        project["id"],
        last_half_start,
        last_half_end,
        filter_input
      );
      const first_data = await this.getAwsCostAndUsage(
        project["id"],
        first_half_start,
        first_half_end,
        filter_input
      );

      // As not given month, but last X days are needed,
      // here costs are extracted and summed.
      last_data.ResultsByTime?.map(value => {
         if (value.Groups.length > 0) {
           value.Groups.forEach(item => {
             const key = item.Keys[0].replace(this.tag_key + '$', '')
                 || this.default_tag_val;
             const val = parseFloat(item.Metrics.UnblendedCost.Amount);
             const collection = last_costs.get(key);
             if (!collection) {
               last_costs.set(key, [val]);
             } else {
               collection.push(val);
             }
           });
         } else {
           const key =
            options.product.toLowerCase() === "projects"
              ? project["id"]
              : this.default_tag_val;
           const val = parseFloat(value.Total?.UnblendedCost.Amount);
           const collection = last_costs.get(key);
           if (!collection) {
             last_costs.set(key, [val]);
           } else {
             collection.push(val);
           }
         }
      });
      first_data.ResultsByTime?.map(value => {
         if (value.Groups.length > 0) {
           value.Groups.forEach(item => {
             const key = item.Keys[0].replace(this.tag_key + '$', '')
                 || this.default_tag_val;
             const val = parseFloat(item.Metrics.UnblendedCost.Amount);
             const collection = first_costs.get(key);
             if (!collection) {
               first_costs.set(key, [val]);
             } else {
               collection.push(val);
             }
           });
         } else {
           const key =
            options.product.toLowerCase() === "projects"
              ? project["id"]
              : this.default_tag_val;
           const val = parseFloat(value.Total?.UnblendedCost.Amount);
           const collection = first_costs.get(key);
           if (!collection) {
             first_costs.set(key, [val]);
           } else {
             collection.push(val);
           }
         }
      });

    }

    const aggregation_map = new Map<string, number[]>();
    last_costs.forEach( (val, key) => {
       aggregation_map.set(
         key,
         [
           0,
           val.reduce(
             (a, b) => a + b,
             0)
         ]
       );
    });
    first_costs.forEach( (val, key) => {
       const collection = aggregation_map.get(key);
       if (!collection) { // the tag didn't exist in last X days
         aggregation_map.set(
           key,
           [
             val.reduce(
               (a, b) => a + b,
               0),
             0
           ]
         );
        } else { // the tag did exist
         collection[0] += val.reduce(
               (a, b) => a + b,
               0);
        }
    });

    aggregation_map.forEach( (aggregation, key) => {
      // Add child Entity to services
      entity.entities.services.push({
        id: key,
        aggregation: aggregation,
        change: changeOf([
          { amount: aggregation[0] },
          { amount: aggregation[1] }
        ]),
        entities: {}
      });

      // Add to costs for all projects
      // at the top of the Entity
      entity.aggregation[0] += aggregation[0];
      entity.aggregation[1] += aggregation[1];
    });

    // Calculate change of
    // costs at the top of the Entity
    entity.change = changeOf([
      { amount: entity.aggregation[0] },
      { amount: entity.aggregation[1] }
    ]);

    return entity;
  }
}
EOF

sed -i "36i\    \"@aws-sdk/client-cost-explorer\": \"^3.95.0\"," ${INSTALL_DIR}/packages/app/package.json
sed -i "69i\    \"repeating-interval\": \"^1.1.0\"," ${INSTALL_DIR}/packages/app/package.json
sed -i "37i\import { CostInsightsClient } from './CostInsightsClient.ts';" ${INSTALL_DIR}/packages/app/src/apis.ts
sed "67s/ExampleCostInsightsClient/CostInsightsClient/" -i ${INSTALL_DIR}/packages/app/src/apis.ts

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
