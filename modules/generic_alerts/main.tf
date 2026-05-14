########################################################
# Module main.tf                                       #
# Purpose: Define the module to create the alert groups with rules #
########################################################

# Define the alert rule group resource that will create a Grafana Alert Group per system
resource "grafana_rule_group" "generic_group" {
  # Name of the alert group, using the system name passed form the root
  name             = "${var.system_name} - Generic Alerts"
  # Folder to create the group there (devops-dash)
  folder_uid       = "<grafana-folder-uid>"
  # Evaluation interval for the alert group
  interval_seconds = 60
  # Enables editing from Grafana UI
  disable_provenance = true

  # Dynamic, to create many rules for only one group using for_each
  dynamic "rule" {
    # Loop over each server in the system's servers list and alert combinations created in locals.tf to create alert rules per server
    for_each = local.alert_rule_pairs

    content {
      # Name of the alert, using the alert pairs and server names
      name      = "${rule.value.server.name} - ${rule.value.alert_name}"
      # The condition refferes to expression to alert
      condition = "B"

      # First data block: OS-specific query using either IP or URL depending on alert type
      data {
        ref_id = "A"
        relative_time_range {
          from = 600
          to   = 0
        }
        # Managed Mimir datasource, passed from root variables.tf
        datasource_uid = var.datasource_uid

        # Replace 'ip' or 'url' placeholder in query with actual server value depending on the alert type
        model = (
          rule.value.alert_key == "cert_exp" || rule.value.alert_key == "state"
          ? replace(local.queries[var.os][rule.value.alert_key], "ip", rule.value.server.url)
          : replace(local.queries[var.os][rule.value.alert_key], "ip", rule.value.server.ip)
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
        model          = local.exprs[rule.value.alert_key]
      }

      # Handling to data and no execution errors
      no_data_state  = "NoData"
      exec_err_state = "Error"

      # Important annotations to get more information about the alert (Then passes it to webhook/FaaS)
      annotations = {
        description = var.alert_types[rule.value.alert_key].description
        summary     = var.alert_types[rule.value.alert_key].summary
      }
      # Important alerts to get more information about the alert (Then passes it to webhook/FaaS)
      labels = {
        instance  = "${rule.value.server.name}"
        severity  = var.alert_types[rule.value.alert_key].severity
        alertname = "${rule.value.server.name} - ${rule.value.alert_name}"
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
