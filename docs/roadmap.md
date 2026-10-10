# Roadmap

## Phase 1 - core platform

- Compose stack
- persistent volumes
- Grafana Loki/Jaeger data sources
- Zabbix first-login setup

## Phase 2 - infrastructure monitoring

- Proxmox hosts
- Zabbix Agent 2 on Linux VMs
- Windows Agent 2
- host groups and tags
- maintenance windows

## Phase 3 - alerting

- email notification channel
- severity policy
- escalation for High/Disaster
- maintenance suppression

## Phase 4 - applications

- web applications
- business applications
- databases
- workflow automation services
- network connectivity services
- CI/CD workers

## Phase 5 - logs

- application log sources into OTLP
- system/service log collection
- correlation fields and retention policy

## Phase 6 - tracing

- instrument a small application first
- validate end-to-end trace collection
- add Grafana-to-Jaeger navigation

## Phase 7 - optimization

Only add another component if a documented workload requires it. Candidate additions are deliberately excluded from the baseline until there is evidence of need.
