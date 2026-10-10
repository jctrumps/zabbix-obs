# Runbook: host unavailable

1. Check the Zabbix problem and last-seen timestamp.
2. Check the Proxmox/VM console if available.
3. Confirm power, node, and storage health.
4. Check recent Zabbix and Loki logs for the host.
5. If the VM is running but unreachable, test its network path and firewall.
6. If memory pressure/OOM is suspected, review the preceding 15-30 minutes of system logs.
7. Record the root cause and update the monitoring rule if it would improve detection.
