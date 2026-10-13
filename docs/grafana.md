# Grafana integration

Grafana loads the third-party `alexanderzobnin-zabbix-app` data source plugin at startup. The plugin version is pinned in `.env.example`.

The Zabbix data source is intentionally not pre-provisioned because the first Zabbix database starts with its bootstrap administrator account. Do not put the Zabbix administrator password into Git merely to automate the first connection.

## One-time setup

1. Deploy and establish workstation SSH forwarding using [the first-run guide](windows-wsl-ansible.md).
2. **ZABBIX WEB UI:** open `http://localhost:8080` through that forwarding and immediately change the bootstrap administrator password.
3. **ZABBIX WEB UI:** under **Users → User groups**, create a Grafana readers group and give it **Read** permissions only on the intended host groups. Under **Users → Users**, create a dedicated Grafana integration user in that group with a regular User role (not Admin/Super admin) and API access. Under **Users → API tokens**, create an expiring token for that user. Store its value in your secrets manager; the token inherits the user's permissions.
4. **GRAFANA WEB UI:** open `http://localhost:3000`, then **Connections → Data sources → Add new data source → Zabbix**.
5. Use:

```text
URL: http://zabbix-web:8080/api_jsonrpc.php
Auth: user/password or API token
Trends: enabled
```

6. **GRAFANA WEB UI:** select API token authentication, enter the token through the UI, then **Save & test**. Query a host from an allowed group and verify that excluded groups remain unavailable. For authorization failures check token expiry, user-role API access and host-group Read permissions; do not substitute a super-administrator token.

The current Zabbix Grafana plugin supports user/password and API-token authentication and can query metrics, problems, triggers, annotations and template variables. It also supports optional direct database connections for long-range queries. Keep Direct DB Connection disabled initially; add it only when long-range dashboard performance requires it.

Create named Grafana accounts and teams for people; do not share the administrator login. The Loki and Jaeger data sources are provisioned as non-editable to prevent configuration drift. Grafana's `.env` administrator password initializes a new database only, while `GRAFANA_SECRET_KEY` must remain stable so Grafana can decrypt saved data-source credentials.
