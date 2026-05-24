<div align="center">

# grafana-alerts

**Terraform module that auto-generates Grafana alert rule groups for Linux and Windows servers from a single config file.**

[![Terraform](https://img.shields.io/badge/Terraform-≥1.0-5C4EE5?logo=terraform&logoColor=white)](https://www.terraform.io/)
[![Grafana Provider](https://img.shields.io/badge/hashicorp%2Fgrafana-4.1.0-F46800?logo=grafana&logoColor=white)](https://registry.terraform.io/providers/hashicorp/grafana/4.1.0)
[![Backend](https://img.shields.io/badge/state-S3%20compatible-569A31?logo=amazons3&logoColor=white)](https://developer.hashicorp.com/terraform/language/backend/s3)
[![PromQL](https://img.shields.io/badge/queries-PromQL-E6522C?logo=prometheus&logoColor=white)](https://prometheus.io/docs/prometheus/latest/querying/basics/)

</div>

---

## What is this?

Setting up Grafana alert rules manually for dozens of servers is tedious and error-prone — every server needs the same six alerts configured individually through the UI. This module lets you declare your systems and servers in a single `terraform.tfvars` file and have Terraform create (or destroy) all the corresponding Grafana alert rule groups automatically.

It supports **Linux and Windows** with OS-specific PromQL queries, lets you suppress specific alerts per server via skip flags, and handles custom system-specific alerts exported directly from the Grafana UI. State is stored remotely in any S3-compatible store (MinIO, Ceph, AWS S3) so the module is safe to use in a team environment.

---

## Features

| | Feature |
|---|---|
| 🐧 🪟 | OS-specific PromQL queries for Linux and Windows |
| 🔔 | Six built-in alert types per server: CPU, memory, storage, SSL cert, backup, and uptime |
| 🚩 | Per-server skip flags to suppress alerts that don't apply (`skip_backup`, `skip_cert`, `skip_state`) |
| 🔧 | Custom system-specific alerts via Grafana Terraform export — no module code changes needed |
| 🔑 | Credentials via environment variables only — nothing sensitive in `.tf` files or state |
| 🗄️ | Remote state in any S3-compatible object store |
| ♻️ | Stable `for_each` keys — reordering systems in `tfvars` never triggers resource replacements |

---

## Architecture

```
terraform.tfvars
┌─────────────────────────────────────────────────┐
│  systems        → list of systems + servers     │
│  specific_alert_types → custom alert defs       │
│  folder_uid, datasource_uid, contact_point_name │
└────────────────────┬────────────────────────────┘
                     │  for_each system
          ┌──────────┴──────────┐
          │                     │
          ▼                     ▼
  module/generic_alerts  module/specific_alerts
  ───────────────────    ──────────────────────
  cpu, memory, storage,  Custom alerts exported
  cert_exp, backup,      from Grafana UI; keyed
  state — OS-specific    by server or __system__
  PromQL queries
          │                     │
          └──────────┬──────────┘
                     │  grafana_rule_group (one per system per module)
                     ▼
           Grafana Alert Rules
           ──────────────────
           Routed to contact point
           (Slack, email, PagerDuty…)
```

**How alert rules are built:**
1. `locals.tf` in each module flattens `servers × alert_types` into a map keyed by `"ServerName|alert_key"`.
2. Server skip flags are evaluated and matching pairs are filtered out.
3. A single `grafana_rule_group` is created per system with a `dynamic "rule"` block — one rule per remaining pair.
4. Each rule has two data blocks: **A** (PromQL query against Prometheus/Mimir) and **B** (threshold expression). The `__IP__` placeholder in query strings is replaced at apply-time with the server's real IP or URL.

---

## Quick Start

**Prerequisites:** Terraform installed, Grafana reachable, Prometheus/Mimir datasource configured in Grafana.

### 1. Clone the repo

```bash
git clone <repo-url>
cd grafana-alerts
```

### 2. Configure the S3 backend

Edit the `backend "s3"` block in [main.tf](main.tf) with your bucket details:

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

### 4. Export credentials as environment variables

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

## Configuration Reference

### Root variables (`variables.tf`)

| Variable | Type | Required | Description |
|---|---|---|---|
| `systems` | `list(object)` | Yes | Systems and their servers (see below) |
| `folder_uid` | `string` | Yes | UID of the Grafana folder to create alerts in |
| `datasource_uid` | `string` | Yes | UID of the Prometheus/Mimir datasource |
| `contact_point_name` | `string` | Yes | Grafana contact point for all notifications |
| `specific_alert_types` | `map(map(map))` | No | Custom per-system alerts (default: `{}`) |

### Server object fields

| Field | Type | Default | Description |
|---|---|---|---|
| `name` | `string` | — | Display name; used in alert rule titles and the `instance` label |
| `ip` | `string` | — | `host:port` used as the Prometheus `instance` label (e.g. `10.0.0.1:9100`) |
| `url` | `string` | — | Full URL used by Blackbox exporter for `cert_exp` and `state` checks |
| `skip_backup` | `bool` | `false` | Suppress the backup alert for this server |
| `skip_cert` | `bool` | `false` | Suppress the SSL certificate expiry alert |
| `skip_state` | `bool` | `false` | Suppress the uptime/state alert |

### Environment variables

| Variable | Used by | Description |
|---|---|---|
| `GRAFANA_URL` | Grafana provider | Base URL of your Grafana instance |
| `GRAFANA_AUTH` | Grafana provider | Service account token |
| `AWS_ACCESS_KEY_ID` | S3 backend | Access key for remote state storage |
| `AWS_SECRET_ACCESS_KEY` | S3 backend | Secret key for remote state storage |

### Built-in alert types (generic_alerts)

| Alert key | Severity | Trigger condition | Query target |
|---|---|---|---|
| `cpu` | High | CPU usage > 95% | `server.ip` |
| `memory` | Critical | Memory usage > 95% | `server.ip` |
| `storage` | Critical | Disk usage > 95% | `server.ip` |
| `cert_exp` | High | SSL cert expires in < 14 days | `server.url` |
| `backup` | High | Backup failed or not running | `server.ip` |
| `state` | Critical | Server/service is down | `server.url` |

---

## Project Structure

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

## Customisation

### Suppress an alert for one server

Add the skip flag to the server object in `terraform.tfvars` — no module changes needed:

```hcl
{ name = "db-backup-01", ip = "10.0.0.5:9100", url = "https://db.example.com", skip_backup = true }
```

### Add a system-specific (custom) alert

1. **Create the alert manually in Grafana UI** with the correct PromQL query and threshold.
2. Open the rule → `...` menu → **Export → Export as Terraform HCL**.
3. Copy the two `model` JSON strings:
   - `ref_id = "A"` → this is your `query`
   - `ref_id = "B"` (datasource `"__expr__"`) → this is your `expr`
4. In the `query` string, replace the server's IP/URL with the placeholder `__IP__`.
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
    # Use "__system__" as the key for alerts that don't map to a specific server
    "__system__" = {
      db_replication_lag = { ... }
    }
  }
}
```

### Add a new generic alert type

1. Add a key to the `alert_types` default map in [modules/generic_alerts/variables.tf](modules/generic_alerts/variables.tf).
2. Add matching `queries["linux"]["new_key"]` and `queries["windows"]["new_key"]` entries in [modules/generic_alerts/locals.tf](modules/generic_alerts/locals.tf).
3. Add the threshold `exprs["new_key"]` entry in the same file.

---

## License

[MIT](LICENSE) © 2026 Michael Goldenberg
