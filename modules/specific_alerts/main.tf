########################################################
# Module main.tf                                       #
# Purpose: Define the module to create the alert groups with rules #
########################################################

# Define the alert rule group resource that will create a Grafana Alert Group per system
resource "grafana_rule_group" "specifc_group" {
  # Name of the alert group, using the system name passed form the root
  name             = "${var.system_name} - Specific Alerts"
  # Folder to create the group there (devops-dash)
  folder_uid       = "<grafana-folder-uid>"
  # Evaluation interval for the alert group
  interval_seconds = 60
  # Enables editing from Grafana UI
  disable_provenance = true

  # Dynamic, to create many rules for only one group using for_each
  dynamic "rule" {
    for_each = local.system_specific_alerts
    # Loop over each server in the system's servers list and alert combinations created in locals.tf to create alert rules per server

    content {
      # Name of the alert, using the alert pairs and server names
      name      = "${rule.value.server_name} - ${rule.value.alert_meta.display_name}"
      # The condition refferes to expression to alert
      condition = "B"

      # First data block: using IP and module from alert types variable
      data {
        ref_id = "A"
        relative_time_range {
          from = 600
          to   = 0
        }
        # Managed Mimir datasource, passed from root variables.tf
        datasource_uid = var.datasource_uid

        # Replace 'ip' placeholder in query with actual server value
        model = (
          rule.value.server != null
          ? replace(rule.value.alert_meta.query, "ip", rule.value.server.ip)
          : rule.value.alert_meta.query
        )
      }

      # Second data block: generic expression to evaluate alert condition
      data {
        ref_id = "B"
        relative_time_range {
          from = 0
          to   = 0
        }
        datasource_uid = "__expr__"
        model          = rule.value.alert_meta.expr
      }

      # Handling to data and no execution errors
      no_data_state  = "NoData"
      exec_err_state = "Error"

      # Important annotations to get more information about the alert (Then passes it to webhook/FaaS)
      annotations = {
        description = rule.value.alert_meta.description
        summary     = rule.value.alert_meta.summary
      }
      # Important alerts to get more information about the alert (Then passes it to webhook/FaaS)
      labels = {
        instance  = rule.value.server_name
        severity  = rule.value.alert_meta.severity
        alertname = "${rule.value.server_name} - ${rule.value.alert_meta.display_name}"
      }
      is_paused = false

      # Chooses wich contact point to use when creating the alers
      notification_settings {
        contact_point = var.contact_point_name
        group_by      = null
        mute_timings  = null
      }
    }
  }
}
