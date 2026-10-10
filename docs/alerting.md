# Alerting policy

Zabbix is the authoritative alerting system for infrastructure incidents.

## Severity model

| Severity | Example | Notification |
|---|---|---|
| Information | lifecycle/change event | dashboard only |
| Warning | filesystem > 80% | email/digest |
| Average | memory pressure, service degradation | email |
| High | critical service unavailable | immediate |
| Disaster | critical host/site unavailable | immediate + escalation |

## Alert design rules

- Prefer sustained conditions over single samples.
- Use hysteresis/recovery thresholds where practical.
- Suppress noisy dependencies.
- Use maintenance windows for planned work.
- Avoid duplicate notifications from multiple products.
- Every High/Disaster alert should have a clear first troubleshooting action.

## Example triggers

```text
Filesystem / > 80% for 10m          -> Warning
Filesystem / > 90% for 10m          -> Average
Filesystem / > 95% for 5m           -> High

Swap usage > 80% for 10m             -> Average
Memory pressure critical              -> High

Critical application service stopped  -> High
PostgreSQL unavailable                -> High
Critical website HTTP failure         -> High
SSL expiration <= 14 days             -> Warning
SSL expiration <= 3 days              -> High
```

Thresholds should be tuned to actual workloads rather than copied blindly.
