# -----------------------------------------------------------------------
# Systems list — add a new system by copying one of the blocks below.
# os:   "linux" or "windows"
# ip:   host:port used as the Prometheus instance label
# url:  full URL used by Blackbox exporter (cert_exp and state alerts)
# skip_backup / skip_cert / skip_state: set to true to suppress that
#   alert type for a specific server (defaults to false if omitted).
# -----------------------------------------------------------------------
systems = [
  {
    system_name = "Example System"
    os          = "windows"
    servers = [
      {
        name        = "Example Server Prod"
        ip          = "<ip-address>:<port>"
        url         = "<system-url>"
        skip_backup = true # Prod is excluded from backup alerting
      },
      {
        name      = "Example Server Test"
        ip        = "<ip-address>:<port>"
        url       = "<system-test-url>"
        skip_cert = true # Test environment has no TLS certificate
      }
    ]
  },
  {
    system_name = "Example Linux System"
    os          = "linux"
    servers = [
      {
        name       = "Example Linux Server"
        ip         = "<ip-address>:<port>"
        url        = "<system-url>"
        skip_state = true
      }
    ]
  }
]

datasource_uid = "<datasource-uid>"

folder_uid = "<grafana-folder-uid>"

contact_point_name = "<contact-point-name>"

# -----------------------------------------------------------------------
# Specific alerts — only for systems that need alerts beyond the generic
# set. Keyed by system_name -> server_name -> alert_key.
# Use "__system__" as the server key for alerts not tied to a server.
#
# How to get the query and expr values — see README for the full guide.
# Short version: create the alert manually in Grafana, then export it
# as Terraform (Alert rule -> ... -> Export -> as Terraform), copy the
# model field from the first data block as `query` and the model field
# from the second data block as `expr`. Replace the instance value in
# the query with __IP__ so this module can substitute the real IP.
# -----------------------------------------------------------------------
specific_alert_types = {
  "Example System" = {
    "Example Server Prod" = {
      example_service_alert = {
        display_name = "Example Service State"
        description  = "An example specific alert for demonstration. Customize this for your needs."
        summary      = "Example service is not running."
        severity     = "Critical"
        # Paste the model from Grafana's Terraform export — replace the instance value with __IP__
        query = "<query-from-grafana-export>"
        expr  = "<expr-from-grafana-export>"
      }
    }
  }
}
