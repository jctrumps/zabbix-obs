# Runbook: service unavailable

1. Confirm the Zabbix service trigger.
2. Check whether the host is healthy.
3. Check the service's systemd status or container state.
4. Search Loki for the service name and error level around the incident.
5. If the service is an instrumented application, inspect the Jaeger trace around the affected request.
6. Restore service, verify recovery in Zabbix, then document the root cause.
