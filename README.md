# Grafana Alert Rules Terraform Module

## Contents

1. [Overview](#overview)
2. [File Structure](#file-structure)
3. [Root Module](#root-module)
4. [Module: generic_alerts](#module-generic_alerts)
5. [Module: specific_alerts](#module-specific_alerts)
6. [Key Concepts](#key-concepts)
7. [How to Use](#how-to-use)
8. [How to Get Query and Expression Strings](#how-to-get-query-and-expression-strings)
9. [Extending the Module](#extending-the-module)

---

## Overview

This Terraform module automates the creation of **Grafana alert rule groups** with multiple alert rules per system and server. It supports **Linux** and **Windows** systems, applies OS-specific PromQL queries, and handles conditional alert generation through per-server skip flags.

Terraform state is stored remotely in an **S3-compatible object store** (e.g. MinIO, Ceph). Credentials and the Grafana connection are passed via environment variables — nothing sensitive is stored in `.tf` files or in state.

---

## File Structure

```
root/
├── main.tf              # Backend, provider, and module calls
├── variables.tf         # Root variable declarations
└── terraform.tfvars     # Actual system/server values (fill this in)
modules/
├── generic_alerts/
│   ├── main.tf          # grafana_rule_group with dynamic rules for all servers × alert types
│   ├── variables.tf     # Inputs: servers (with skip flags), alert_types, folder_uid, etc.
│   └── locals.tf        # PromQL queries, threshold expressions, filtered alert_rule_pairs
└── specific_alerts/
    ├── main.tf          # grafana_rule_group with dynamic rules for system-specific alerts
    ├── variables.tf     # Inputs: specific_alert_types (pre-filtered to this system)
    └── locals.tf        # Flattens specific_alert_types into a for_each-compatible map
```

---

## Root Module

### main.tf

- Configures the **S3 backend** for remote state storage. Bucket, region, and endpoint are set here; credentials flow in from environment variables `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY`. The `skip_*` flags and `force_path_style = true` are required for non-AWS S3-compatible stores.
- Configures the **Grafana provider** via `GRAFANA_URL` and `GRAFANA_AUTH` environment variables.
- Calls `generic_alerts` once per system (excluding the example placeholder), using `system_name` as the `for_each` key so reordering entries in `terraform.tfvars` doesn't trigger resource replacements.
- Calls `specific_alerts` only for systems that have entries in `specific_alert_types`, passing only that system's slice of the map.

### variables.tf

- `systems` — list of system objects, each with an OS type and servers (including optional skip flags).
- `folder_uid` — Grafana folder where all alert groups are created.
- `datasource_uid` — Grafana datasource UID (Prometheus/Mimir).
- `contact_point_name` — Grafana contact point for all notifications.
- `specific_alert_types` — optional nested map for system-specific alerts; defaults to empty.

### terraform.tfvars

Provides real values for all variables. This is the primary file to edit when adding a new system or server.

---

## Module: generic_alerts

Manages the standard set of alerts (cpu, memory, storage, cert_exp, backup, state) that apply to every system. A single `grafana_rule_group` is created per system call, containing one rule per server × alert type combination after filtering.

### variables.tf

Key inputs:
- `servers` — each server object supports three optional boolean flags:
  - `skip_backup` — suppress backup alert for this server (default: `false`)
  - `skip_cert` — suppress certificate expiry alert (default: `false`)
  - `skip_state` — suppress uptime/state alert (default: `false`)
- `folder_uid` — the target Grafana folder.
- `alert_types` — map of alert configs with a sensible default covering all six alert types.

### locals.tf

- **`alert_rule_pairs`** — flattens every server × alert type combination into a single map keyed by `"ServerName|alert_key"`, then filters out pairs where the server's skip flag is set.
- **`queries`** — two-level map (`os → alert_key → JSON string`) containing the PromQL query for each alert. The server's address is represented by the placeholder `__IP__`, which is replaced at apply-time.
- **`exprs`** — map of threshold expressions (`alert_key → JSON string`) used as the condition in data block B.

### main.tf

- Creates a `grafana_rule_group` with a `dynamic "rule"` block iterating over `local.alert_rule_pairs`.
- For `cert_exp` and `state` alerts, `__IP__` is replaced with `server.url` (Blackbox exporter targets a URL). All other alerts replace `__IP__` with `server.ip`.
- Each rule has two data blocks: A (PromQL query) and B (threshold expression), with `condition = "B"`.

---

## Module: specific_alerts

Handles alerts that are unique to a particular system and don't fit the generic pattern — for example, monitoring a specific Windows service, a custom application metric, or a non-standard port check.

### How it works

- The root passes `var.specific_alert_types[system_name]` — only this system's entries — so the module has a clean, minimal interface.
- `locals.tf` flattens the two-level map (`server_name → alert_key → config`) into the same `"ServerName|alert_key"` map shape used by `generic_alerts`.
- Use `"__system__"` as the server key for alerts that apply to the system as a whole rather than a specific server. The alert's `instance` label will be set to the system name.
- Each alert config includes `query` and `expr` — full JSON strings from Grafana's Terraform export. The `__IP__` placeholder in `query` is replaced with `server.ip` at apply-time.

---

## Key Concepts

- **Dynamic blocks** — generate multiple alert rules per system without repeating code.
- **Per-server skip flags** — `skip_backup`, `skip_cert`, `skip_state` on each server object control which alerts are created, without touching module internals.
- **Stable `for_each` keys** — both module calls use `system_name` as the map key instead of the list index, so reordering systems in `terraform.tfvars` won't cause unintended resource replacements.
- **`__IP__` placeholder** — all PromQL query strings use `__IP__` where the server address goes. Terraform replaces it with the real IP (or URL) at apply-time. This avoids accidental substring matches that a bare `ip` placeholder could cause.
- **Pre-filtered specific alerts** — the root passes only `specific_alert_types[system_name]` to the `specific_alerts` module, keeping the module interface simple and the plan output clean.
- **Remote state via S3** — `terraform.tfstate` is stored in an S3-compatible bucket. No local state files are committed to the repository.

---

## How to Use

1. Fill in `terraform.tfvars` with your systems, servers, folder UID, datasource UID, and contact point name.
2. Set environment variables before running Terraform:
   ```bash
   export GRAFANA_URL="https://grafana.example.com"
   export GRAFANA_AUTH="<service-account-token>"
   export AWS_ACCESS_KEY_ID="<s3-access-key>"
   export AWS_SECRET_ACCESS_KEY="<s3-secret-key>"
   ```
3. Update the `backend "s3"` block in `main.tf` with your bucket name, region, and endpoint.
4. Run:
   ```bash
   terraform init
   terraform plan
   terraform apply
   ```

---

## How to Get Query and Expression Strings

The `query` and `expr` values in `specific_alert_types` (and the base queries in `generic_alerts/locals.tf`) are JSON strings that Grafana uses internally to describe a data query and a threshold expression. The easiest way to get them is to export an existing alert from Grafana:

1. **Create the alert manually in Grafana UI** — set up the alert rule exactly as you want it, with the correct PromQL query and threshold.
2. **Open the alert rule** — go to Alerting → Alert rules and open the rule you just created.
3. **Export as Terraform** — click the `...` menu on the rule, then choose **Export → Export as Terraform HCL**.
4. **Copy the `model` fields** — in the exported HCL, each `data` block has a `model` attribute containing a JSON string:
   - The first `data` block (`ref_id = "A"`) — this is your `query` value.
   - The second `data` block (`ref_id = "B"`, `datasource_uid = "__expr__"`) — this is your `expr` value.
5. **Replace the instance value** — in the `query` string, find the `instance` label value (it will be your server's actual IP or URL) and replace it with `__IP__`. This module will substitute the real value at apply-time.
6. **Paste into `terraform.tfvars`** — add the strings under the appropriate system/server keys in `specific_alert_types`.

> The same process was used to build the base queries in `generic_alerts/locals.tf` — one alert per type was created manually, exported, and the instance value was replaced with `__IP__`.

---

## Extending the Module

- **Add a generic alert type** — add a new key to the `alert_types` default in `generic_alerts/variables.tf`, add matching `query` entries for both `linux` and `windows` in `generic_alerts/locals.tf`, and add the threshold `expr` entry in the same file.
- **Add a system-specific alert** — add an entry under `specific_alert_types` in `terraform.tfvars` following the existing example. No module code changes needed.
- **Add a new system** — add a new object to the `systems` list in `terraform.tfvars`.
- **Export alert group IDs** — add an `outputs.tf` file at the root if you need to reference the created alert group UIDs elsewhere.
