########################################################
# Module main.tf                                       #
# Purpose: Create one Grafana alert group per system  #
#          for alerts that are unique to that system   #
#          and don't fit the generic alert pattern     #
########################################################

resource "grafana_rule_group" "specific_group" {
  name               = "${var.system_name} - Specific Alerts"
  folder_uid         = var.folder_uid
  interval_seconds   = 60
  disable_provenance = true

  dynamic "rule" {
    for_each = local.system_specific_alerts

    content {
      name      = "${rule.value.server_name} - ${rule.value.alert_meta.display_name}"
      condition = "B"

      # Data block A: query provided directly in specific_alert_types.
      # Replace __IP__ placeholder with the real server IP if a server is set.
      # System-level alerts (server == null) use the query as-is.
      data {
        ref_id = "A"
        relative_time_range {
          from = 600
          to   = 0
        }
        datasource_uid = var.datasource_uid
        model = (
          rule.value.server != null
          ? replace(rule.value.alert_meta.query, "__IP__", rule.value.server.ip)
          : rule.value.alert_meta.query
        )
      }

      # Data block B: threshold expression provided directly in specific_alert_types
      data {
        ref_id = "B"
        relative_time_range {
          from = 0
          to   = 0
        }
        datasource_uid = "__expr__"
        model          = rule.value.alert_meta.expr
      }

      no_data_state  = "NoData"
      exec_err_state = "Error"

      annotations = {
        description = rule.value.alert_meta.description
        summary     = rule.value.alert_meta.summary
      }

      labels = {
        instance  = rule.value.server_name
        severity  = rule.value.alert_meta.severity
        alertname = "${rule.value.server_name} - ${rule.value.alert_meta.display_name}"
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
