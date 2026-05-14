# Local values defining reusable maps and filtering logic for alert rules
locals {
  # Map servers by name for O(1) lookup when building alert pairs
  server_map = {
    for server in var.servers :
    server.name => server
  }

  #----------------------------------------------------------------------#
  # Flatten the alerts into a map keyed by "serverName|alertKey"        #
  # so for_each in main.tf can iterate over them like generic alerts.   #
  # var.specific_alert_types is already filtered to this system only     #
  # (the root passes specific_alert_types[system_name]).                 #
  # Use "__system__" as the server key for alerts not tied to a server. #
  #----------------------------------------------------------------------#
  system_specific_alerts = merge([
    for server_name, alerts in var.specific_alert_types : {
      for alert_key, alert_cfg in alerts :
        "${server_name}|${alert_key}" => {
          # Resolve the server object; __system__ alerts have no server
          server      = server_name == "__system__" ? null : lookup(local.server_map, server_name, null)
          server_name = server_name == "__system__" ? var.system_name : server_name
          alert_key   = alert_key
          alert_meta  = alert_cfg
        }
    }
  ]...)
}
