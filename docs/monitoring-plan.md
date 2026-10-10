# Monitoring plan

## Phase 1: platform itself

Monitor the `obs-01` host and the Zabbix stack:

- CPU/load
- RAM/swap
- filesystem capacity
- disk I/O
- network
- Docker daemon
- PostgreSQL service
- Zabbix server
- Grafana
- Loki
- OpenTelemetry Collector
- Jaeger

## Phase 2: Proxmox

Add the Proxmox hosts and monitor:

- host availability
- CPU/load
- memory and swap
- storage pools
- storage capacity
- network interfaces
- VM state
- VM CPU and memory
- guest availability

## Phase 3: guest operating systems

Linux:

- Zabbix Agent 2
- filesystem usage
- memory pressure
- swap
- important systemd services
- process health
- network

Windows:

- Zabbix Agent 2
- CPU/memory/disk
- important Windows services
- event-log checks where useful

## Phase 4: applications

Select checks for the applications you deploy, for example:

- web servers and HTTP endpoints
- business applications
- databases
- workflow automation services
- network connectivity services
- CI/CD workers

Use application-specific checks only when they answer a real operational question.

## Phase 5: external services

Web monitoring should include:

- HTTP status
- response time
- TLS certificate expiration
- critical URL checks
- DNS checks where valuable

The goal is not to monitor every metric. The goal is to detect problems early and provide enough evidence to diagnose them.
