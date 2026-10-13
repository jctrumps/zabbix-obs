# Manual Cloudflare Tunnel

Optional, after [internal verification](windows-wsl-ansible.md#g--verify-internally-and-complete-first-run-setup).
No Terraform/OpenTofu, Ansible, Compose or script in this project creates tunnels,
DNS, Access policies, tokens or connector configuration.

## Origin routing and connector location

| Application | Same-VM host connector origin | Example public hostname |
|---|---|---|
| Zabbix | `http://127.0.0.1:8080` | `zabbix.example.com` |
| Grafana | `http://127.0.0.1:3000` | `grafana.example.com` |
| Jaeger (optional, admin-only) | `http://127.0.0.1:16686` | `traces.example.com` |

These are the default host ports; use local overrides if different. Prefer a
connector manually installed as a **host service on the same VM**. Loopback
ports are accessible there. A bridge-networked connector container has its own
loopback and cannot use those host-loopback URLs without an explicitly chosen
host-network/routing arrangement. A connector on a different host also cannot
reach the VM's `127.0.0.1`; use authenticated/encrypted private connectivity to
a deliberately bound VM interface and restrict origin access to the connector.
Do not change every bind address to `0.0.0.0` as a tunnel fix.

## Manual setup

1. **REMOTE VM:** confirm Zabbix, Grafana and Jaeger return successful local
   responses using the commands in [operations](operations.md).
2. **CLOUDFLARE DASHBOARD:** in Zero Trust, create a remotely managed tunnel
   under Networks/Tunnels (menu names may change). Select the Linux connector
   installation instructions for your chosen host. Install the connector
   manually on the **REMOTE VM** using the exact dashboard-provided command.
   Its token is a secret; do not paste it into repository files, tickets or ZIPs.
3. **CLOUDFLARE DASHBOARD:** wait for a healthy connector. Add a public hostname
   and HTTP service using the appropriate table origin. Review/create its DNS
   record manually in the dashboard. Use your own domain only in local settings.
4. **CLOUDFLARE DASHBOARD:** create an Access self-hosted application for each
   admin hostname; allow only intended identities/groups, preferably with MFA.
   Jaeger has no login, so protect it before enabling external access. Zabbix
   and Grafana still need their application accounts and permissions.
5. **WSL / UBUNTU BASH**, `deploy/ansible`: edit `inventory/vars.yml` and set
   `grafana_root_url: https://grafana.example.com` using your actual hostname;
   redeploy through [daily deployment](daily-deployment.md).
6. **ZABBIX WEB UI:** set the frontend URL used in notifications/integrations
   to your external HTTPS URL (Administration → General → Other in Zabbix 7.4).
   Update any generated alert links and integration callback URLs. The baseline
   installs no inbound webhook receiver or OAuth client. If you add SSO later,
   register its exact HTTPS callback with the identity provider and ensure Access
   policies do not block that flow.

Use Cloudflare HTTPS at the public edge. Same-host loopback HTTP is the baseline
origin transport; a remote origin needs an explicitly secured network/HTTPS
arrangement. Leave Grafana serving HTTP locally and use the HTTPS `root_url` for
redirects. Validate forwarded scheme/host behavior before enabling OAuth/SSO.
Avoid blanket Access bypasses for APIs/webhooks; configure narrowly scoped
service authentication only when an integration actually requires it.

## Verify and troubleshoot

**WINDOWS CMD**, after replacing example hostnames:

```bat
curl.exe -I https://grafana.example.com
curl.exe -I https://zabbix.example.com
```

An Access login redirect for an unauthenticated request is expected. Test in a
browser as both an allowed and denied identity. Confirm HTTPS URLs, login,
redirects and Grafana data-source connectivity. Internal data sources use Docker
DNS and should not be pointed at an Access-protected public URL.

| Symptom | Diagnostic location | Fix |
|---|---|---|
| Tunnel unhealthy / 1033 | Dashboard connector status; REMOTE VM `sudo systemctl status cloudflared` | Correct manual connector installation and outbound network access |
| 502 from edge | REMOTE VM `curl -I http://127.0.0.1:3000`; connector service logs | Correct origin port/protocol and connector location; restore app health |
| Redirects to localhost / login loop | Browser redirect headers, local `grafana_root_url` | Use exact external HTTPS URL and redeploy; check forwarded headers |
| 403 / Access loop | Dashboard Access policy and identity | Correct allowed identity/application domain; retain Access protection |
| DNS failure | WINDOWS CMD `nslookup grafana.example.com` | Correct manual public hostname/DNS record |

Connector tokens/configuration and logs belong outside source control and source
archives. Next: [operations](operations.md) and [public release](public-release.md).
