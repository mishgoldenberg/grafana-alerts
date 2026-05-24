<div align="center">

# 🔔 Grafana Alert Rules

**Terraform module that auto-generates Grafana alert rule groups for Linux and Windows servers — from a single config file.**

[![Terraform](https://img.shields.io/badge/Terraform-≥1.0-5C4EE5?style=for-the-badge&logo=terraform&logoColor=white)](https://www.terraform.io/)
[![Grafana Provider](https://img.shields.io/badge/Grafana_Provider-4.1.0-F46800?style=for-the-badge&logo=grafana&logoColor=white)](https://registry.terraform.io/providers/hashicorp/grafana/4.1.0)
[![Backend](https://img.shields.io/badge/Backend-S3_Compatible-569A31?style=for-the-badge&logo=amazons3&logoColor=white)](https://developer.hashicorp.com/terraform/language/backend/s3)
[![PromQL](https://img.shields.io/badge/Queries-PromQL-E6522C?style=for-the-badge&logo=prometheus&logoColor=white)](https://prometheus.io/docs/prometheus/latest/querying/basics/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow?style=for-the-badge)](LICENSE)

</div>

---

## What is this?

Setting up Grafana alert rules manually for dozens of servers is tedious and error-prone — every server needs the same six alerts configured individually through the UI. This module lets you declare your systems and servers in a single `terraform.tfvars` file and have Terraform create (or destroy) all the corresponding Grafana alert rule groups automatically.

It supports **Linux and Windows** with OS-specific PromQL queries, lets you suppress specific alerts per server via skip flags, and handles custom system-specific alerts exported directly from the Grafana UI. State is stored remotely in any S3-compatible store (MinIO, Ceph, AWS S3) so the module is safe to use in a team environment.

---

## ✨ Features

| | |
|---|---|
| 🐧 🪟 **Cross-platform** | OS-specific PromQL queries for both Linux and Windows servers |
| 🔔 **Six built-in alerts** | CPU, memory, storage, SSL cert expiry, backup, and uptime — per server |
| 🚩 **Per-server skip flags** | Suppress alerts that don't apply without touching module internals |
| 🔧 **Custom alerts** | Add system-specific alerts via Grafana Terraform export — no module changes needed |
| 🔑 **Credentials via env vars** | Nothing sensitive in `.tf` files or state |
| 🗄️ **Remote state** | Terraform state stored in any S3-compatible object store |
| ♻️ **Stable keys** | `system_name`-keyed `for_each` — reordering systems never triggers replacements |

---

## 🏗️ How it works

```
terraform.tfvars
       │
       ├── systems (list of systems + servers)
       ├── specific_alert_types (custom alert defs)
       └── folder_uid, datasource_uid, contact_point_name
       │
       │  for_each system
       ├──────────────────────────────────┐
       ▼                                  ▼
module/generic_alerts            module/specific_alerts
─────────────────────            ──────────────────────
cpu, memory, storage,            Custom alerts exported
cert_exp, backup, state          from Grafana UI; keyed
with OS-specific PromQL          by server or __system__
       │                                  │
       └──────────────┬───────────────────┘
                      │  grafana_rule_group (one per system per module)
                      ▼
            Grafana Alert Rules
            ─────────────────────────────
            Routed to contact point
            (Slack, email, PagerDuty…)
```

**How rules are built:**
1. Each module's `locals.tf` flattens `servers × alert_types` into a map keyed by `"ServerName|alert_key"`.
2. Per-server skip flags are evaluated and matching pairs are filtered out.
3. A single `grafana_rule_group` is created per system using a `dynamic "rule"` block.
4. Each rule has two data blocks: **A** (PromQL query) and **B** (threshold expression). The `__IP__` placeholder is replaced at apply-time with the server's real IP or URL.

---

## 🚀 Quick Start

**Prerequisites:** Terraform installed, Grafana reachable, Prometheus/Mimir datasource configured in Grafana.

### 1. Clone

```bash
git clone <repo-url>
cd grafana-alerts
```

### 2. Configure the S3 backend

Edit the `backend "s3"` block in [main.tf](main.tf):

```hcl
backend "s3" {
  bucket   = "my-terraform-state"
  key      = "terraform.tfstate"
  region   = "us-east-1"           # any value for non-AWS stores
  endpoint = "https://minio.example.com"
  skip_credentials_validation = true
  skip_region_validation      = true
  skip_requesting_account_id  = true
  force_path_style            = true
}
```

### 3. Fill in `terraform.tfvars`

```hcl
folder_uid         = "<grafana-folder-uid>"
datasource_uid     = "<prometheus-datasource-uid>"
contact_point_name = "slack-ops"

systems = [
  {
    system_name = "My App"
    os          = "linux"
    servers = [
      {
        name        = "app-prod-01"
        ip          = "10.0.0.1:9100"
        url         = "https://myapp.example.com"
        skip_backup = false
        skip_cert   = false
        skip_state  = false
      }
    ]
  }
]
```

### 4. Set environment variables

```bash
export GRAFANA_URL="https://grafana.example.com"
export GRAFANA_AUTH="<service-account-token>"
export AWS_ACCESS_KEY_ID="<s3-access-key>"
export AWS_SECRET_ACCESS_KEY="<s3-secret-key>"
```

### 5. Apply

```bash
terraform init
terraform plan
terraform apply
```

---

## ⚙️ Configuration Reference

### Root variables

| Variable | Required | Description |
|---|:---:|---|
| `systems` | ✅ | List of systems and their servers (see server fields below) |
| `folder_uid` | ✅ | UID of the Grafana folder to create alerts in |
| `datasource_uid` | ✅ | UID of the Prometheus/Mimir datasource |
| `contact_point_name` | ✅ | Grafana contact point for all notifications |
| `specific_alert_types` | | Custom per-system alerts (default: `{}`) |

### Server object fields

| Field | Required | Description |
|---|:---:|---|
| `name` | ✅ | Display name — used in alert rule titles and the `instance` label |
| `ip` | ✅ | `host:port` for the Prometheus `instance` label (e.g. `10.0.0.1:9100`) |
| `url` | ✅ | Full URL for Blackbox exporter `cert_exp` and `state` checks |
| `skip_backup` | | Suppress the backup alert for this server (default: `false`) |
| `skip_cert` | | Suppress the SSL certificate expiry alert (default: `false`) |
| `skip_state` | | Suppress the uptime/state alert (default: `false`) |

### Environment variables

| Variable | Required | Description |
|---|:---:|---|
| `GRAFANA_URL` | ✅ | Base URL of your Grafana instance |
| `GRAFANA_AUTH` | ✅ | Grafana service account token |
| `AWS_ACCESS_KEY_ID` | ✅ | Access key for S3 remote state |
| `AWS_SECRET_ACCESS_KEY` | ✅ | Secret key for S3 remote state |

### Built-in alert types

| Alert | Severity | Trigger | Query target |
|---|---|---|---|
| `cpu` | High | CPU usage > 95% | `server.ip` |
| `memory` | Critical | Memory usage > 95% | `server.ip` |
| `storage` | Critical | Disk usage > 95% | `server.ip` |
| `cert_exp` | High | SSL cert expires in < 14 days | `server.url` |
| `backup` | High | Backup failed or not running | `server.ip` |
| `state` | Critical | Server/service is down | `server.url` |

---

## 🗂️ Project Structure

```
grafana-alerts/
├── main.tf                   # S3 backend, Grafana provider, module calls
├── variables.tf              # Root input variable definitions
├── terraform.tfvars          # Your systems, servers, and UIDs (edit this)
└── modules/
    ├── generic_alerts/       # Standard 6-alert set for all systems
    │   ├── main.tf           # grafana_rule_group with dynamic rule blocks
    │   ├── variables.tf      # Inputs: servers, skip flags, folder/datasource UIDs
    │   └── locals.tf         # PromQL queries (per OS), threshold exprs, alert_rule_pairs
    └── specific_alerts/      # System-specific custom alerts
        ├── main.tf           # grafana_rule_group for custom alerts
        ├── variables.tf      # Inputs: specific_alert_types (pre-filtered to this system)
        └── locals.tf         # Flattens server × alert map into for_each-compatible map
```

---

## 🔧 Customisation

**Suppress an alert for one server** — add the skip flag in `terraform.tfvars`, no module changes needed:

```hcl
{ name = "db-01", ip = "10.0.0.5:9100", url = "https://db.example.com", skip_backup = true }
```

**Add a system-specific alert:**

1. Create the alert manually in the Grafana UI with the correct PromQL query and threshold.
2. Open the rule → `...` menu → **Export → Export as Terraform HCL**.
3. Copy the two `model` JSON strings — `ref_id = "A"` is your `query`, `ref_id = "B"` is your `expr`.
4. Replace the server's IP/URL in the `query` string with `__IP__`.
5. Add the entry to `specific_alert_types` in `terraform.tfvars`:

```hcl
specific_alert_types = {
  "My App" = {
    "app-prod-01" = {
      windows_service_check = {
        display_name = "Critical Service Down"
        description  = "The MyApp Windows service has stopped."
        summary      = "MyApp service is not running on __IP__"
        severity     = "Critical"
        query        = "<JSON from ref_id A, __IP__ substituted>"
        expr         = "<JSON from ref_id B>"
      }
    }
    # Use "__system__" for alerts that don't map to a specific server
    "__system__" = { ... }
  }
}
```

**Add a new generic alert type** — add a key to `alert_types` in [modules/generic_alerts/variables.tf](modules/generic_alerts/variables.tf), then add matching `queries["linux"]`, `queries["windows"]`, and `exprs` entries in [modules/generic_alerts/locals.tf](modules/generic_alerts/locals.tf).

---

## 📄 License

[MIT](LICENSE) © 2026 Michael Goldenberg
