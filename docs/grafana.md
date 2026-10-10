# Grafana integration

Grafana includes the official Zabbix data source plugin at startup. The plugin version is pinned in `.env.example`.

The Zabbix data source is intentionally not pre-provisioned because the first Zabbix database starts with its bootstrap administrator account. Do not put the Zabbix administrator password into Git merely to automate the first connection.

## One-time setup

1. Start the stack.
2. Log into Zabbix at `http://<host>:8080` and immediately change the bootstrap administrator password.
3. Create a dedicated Zabbix user or API token for Grafana with read access to the host groups Grafana should query.
4. In Grafana, open **Connections -> Data sources -> Add new data source -> Zabbix**.
5. Use:

```text
URL: http://zabbix-web:8080/api_jsonrpc.php
Auth: user/password or API token
Trends: enabled
```

6. Save and test.

The current Zabbix Grafana plugin supports user/password and API-token authentication and can query metrics, problems, triggers, annotations and template variables. It also supports optional direct database connections for long-range queries. Keep Direct DB Connection disabled initially; add it only when long-range dashboard performance requires it.

Create named Grafana accounts and teams for people; do not share the administrator login. The Loki and Jaeger data sources are provisioned as non-editable to prevent configuration drift. Grafana's `.env` administrator password initializes a new database only, while `GRAFANA_SECRET_KEY` must remain stable so Grafana can decrypt saved data-source credentials.
