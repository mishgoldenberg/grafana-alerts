# Local values defining reusable maps and filtering logic for alert rules
locals {
  # Map servers for easy lookup by name
  server_map = {
    for server in var.servers :
    server.name => server
  }

  # Pick only the alerts relevant for the current system
  system_alerts = lookup(var.specific_alert_types, var.system_name, {})

  #----------------------------------------------------------------------#
  # Flatten the alerts into a structure (similar to generic alerts)      #
  # So we can interact with it with for_each                             #
  #----------------------------------------------------------------------#
  system_specific_alerts = merge([
    for server_name, alerts in local.system_alerts : {
      for alert_key, alert_cfg in alerts :
        "${server_name}|${alert_key}" => {
          server = (
            server_name == "__system__" ? null : lookup(local.server_map, server_name, null)
          )
          server_name = server_name == "__system__" ? var.system_name : server_name
          alert_key   = alert_key
          alert_meta  = alert_cfg
        }
    }
  ]...)
}
