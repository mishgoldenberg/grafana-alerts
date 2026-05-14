# Grafana Alert Rules Terraform Module

## Contents

1. [Overview](#overview)
2. [File Structure](#file-structure)
3. [Root Module](#root-module)
4. [Module: generic_alerts](#module-generic_alerts)
   - [main.tf](#maintf)
   - [variables.tf](#variablestf)
   - [locals.tf](#localstf)
5. [Module: specific_alerts](#module-specific_alerts)
6. [Key Concepts](#key-concepts)
7. [How to Use](#how-to-use)
8. [Extending the Module](#extending-the-module)

---

## Overview

This Terraform module automates the creation of **Grafana alert rule groups** with multiple alert rules per system and server. It supports **Linux** and **Windows** systems, applying OS-specific queries, and includes conditional alert generation based on server names and alert types.

---

## File Structure

```
root/
├── main.tf              # Root module main file — calls both modules for each system
├── variables.tf         # Root variable declarations (e.g., list of systems with servers)
└── terraform.tfvars     # Root variable values (systems data with OS, IP, etc.)
modules/
├── generic_alerts/
│   ├── main.tf          # Creates Grafana alert_rule_group resource with dynamic rules
│   ├── variables.tf     # Module input variables (servers, alert_types, datasource_uid, system_name, etc.)
│   └── locals.tf        # OS-specific queries, generic expressions, conditions to skip certain alerts
└── specific_alerts/
    ├── main.tf          # Creates Grafana alert_rule_group resource for system-specific alerts
    ├── variables.tf     # Module input variables including specific_alert_types
    └── locals.tf        # Flattens specific alert definitions into a for_each-compatible structure
```

---

## Root Module

- **main.tf**\
  Loops over the systems list, invoking the `generic_alerts` module for every system (except examples) and the `specific_alerts` module for systems that have entries in `specific_alert_types`. Passes system name, OS, list of servers, and alert configuration.

- **variables.tf**\
  Declares the `systems` variable as a list of objects, each representing a monitored system with OS and server details. Also declares `specific_alert_types` for per-system custom alerts.

- **terraform.tfvars**\
  Provides the actual system data, including system name, OS (`linux` or `windows`), and servers with their `name`, `ip`, and `url`. Also defines any specific alerts per system per server.

---

## Module: generic_alerts

### main.tf

- Defines `grafana_rule_group` resource creating one alert group per system.
- Uses **dynamic blocks** to iterate over server-alert pairs from `locals.tf`.
- Conditional logic filters out irrelevant alerts based on server names and alert types.
- Data blocks within each alert rule contain:
  - OS-specific query (`model`) with the server's IP or URL substituted.
  - Generic expressions evaluating the query results.
- Configures labels, annotations, notification settings, and alert states per rule.

### variables.tf

- Defines inputs such as:
  - `servers` — list of server objects with `name`, `ip`, and `url`.
  - `alert_types` — map of alert keys to descriptive names, descriptions, summaries, and severities. Defaults to cpu, memory, storage, cert_exp, backup, and state.
  - `datasource_uid` — Grafana datasource ID.
  - `system_name` — used for naming the alert rule group.
  - `os` — to select Linux or Windows queries.
  - `contact_point_name` — the Grafana contact point to route alerts to.

### locals.tf

- Contains OS-specific PromQL queries keyed by alert type (`linux` / `windows`).
- Generic evaluation expressions used across all alert types (ref_id `B`).
- Lists of server names for skipping backup, cert expiration, or state alerts.
- Constructs a combined map of server-alert pairs with filtering based on skip lists.

---

## Module: specific_alerts

Handles alerts that are unique to a specific system and don't follow the generic pattern.

- `specific_alert_types` is a three-level map: `system → server → alert_key → alert config`.
- Use `"__system__"` as the server key for alerts that are not tied to a specific server.
- Each alert config includes `display_name`, `description`, `summary`, `severity`, `query`, and `expr` — giving full control over the PromQL query and threshold expression.

---

## Key Concepts

- **Dynamic blocks**: Used extensively to generate multiple alert rules per system/server/alert type without repeating code.
- **Conditional filtering**: Prevents unnecessary alerts from being created for specific server-alert combinations.
- **OS-specific queries**: Different PromQL queries for Linux vs. Windows, stored in `locals.tf`.
- **Variables and locals**: Centralize alert expressions and query templates for easy maintenance and extension.
- **Modular approach**: Root module calls each module once per system, keeping code DRY and scalable.

---

## How to Use

1. Populate `terraform.tfvars` with your systems and servers data.
2. Customize alert queries or add new generic alert types in `modules/generic_alerts/locals.tf`.
3. Add system-specific alerts under `specific_alert_types` in `terraform.tfvars`.
4. Run `terraform init`, `terraform plan`, and `terraform apply` at the root to create all alert groups and rules in Grafana.

---

## Extending the Module

- Add more generic alert types by updating the `alert_types` default in `modules/generic_alerts/variables.tf` and adding the corresponding queries and expressions in `locals.tf`.
- Adjust conditions for skipping alerts by modifying the skip lists in `modules/generic_alerts/locals.tf`.
- Add system-specific alerts by extending the `specific_alert_types` map in `terraform.tfvars`.
- Add outputs in `outputs.tf` if you need to export alert group IDs or other info.
