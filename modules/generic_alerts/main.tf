########################################################
# Module main.tf                                       #
# Purpose: Create one Grafana alert group per system  #
#          with dynamic rules for every server/alert  #
#          type combination defined in locals.tf       #
########################################################

resource "grafana_rule_group" "generic_group" {
  name               = "${var.system_name} - Generic Alerts"
  folder_uid         = var.folder_uid
  interval_seconds   = 60
  disable_provenance = true

  dynamic "rule" {
    for_each = local.alert_rule_pairs

    content {
      name      = "${rule.value.server.name} - ${rule.value.alert_name}"
      condition = "B"

      # Data block A: OS-specific PromQL query with __IP__ replaced by the
      # real server IP, except cert_exp and state which use the server URL
      # (Blackbox exporter targets a URL, not a raw IP).
      data {
        ref_id = "A"
        relative_time_range {
          from = 600
          to   = 0
        }
        datasource_uid = var.datasource_uid
        model = (
          rule.value.alert_key == "cert_exp" || rule.value.alert_key == "state"
          ? replace(local.queries[var.os][rule.value.alert_key], "__IP__", rule.value.server.url)
          : replace(local.queries[var.os][rule.value.alert_key], "__IP__", rule.value.server.ip)
        )
      }

      # Data block B: threshold expression that evaluates the query result from A
      data {
        ref_id = "B"
        relative_time_range {
          from = 0
          to   = 0
        }
        datasource_uid = "__expr__"
        model          = local.exprs[rule.value.alert_key]
      }

      no_data_state  = "NoData"
      exec_err_state = "Error"

      annotations = {
        description = local.alert_types[rule.value.alert_key].description
        summary     = local.alert_types[rule.value.alert_key].summary
      }

      labels = {
        instance  = rule.value.server.name
        severity  = local.alert_types[rule.value.alert_key].severity
        alertname = "${rule.value.server.name} - ${rule.value.alert_name}"
      }

      is_paused = false

      notification_settings {
        contact_point = var.contact_point_name
        group_by      = null
        mute_timings  = null
      }
    }
  }
}
