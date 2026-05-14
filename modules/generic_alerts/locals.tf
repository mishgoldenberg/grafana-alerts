# Local values defining reusable maps and filtering logic for alert rules
locals {
  #----------------------------------------------------------------------#
  # Flatten amp of alert rules, keyed by "serverName|alertKey"           #
  # Each entry contains server data, alert key, and alert display name   #
  #----------------------------------------------------------------------#
  alert_rule_pairs = {
    # Start by merging maps generated for each server
    for pair_key, pair_value in merge([
      # Loop over all servers in var.servers
      for srv in var.servers : {
        # For each server, loop over all alert types
        for alert_key, alert_obj in var.alert_types :
          # Create a unique key "serverName|alertKey" and map it to an object
          "${srv.name}|${alert_key}" => {
            server     = srv                     # Store the server object
            alert_key  = alert_key               # Store the alert type key (e.g. "cpu", "memory")
            alert_name = alert_obj.display_name  # Store the alert's display name (e.g. "CPU Usage is Critical!", "Memory Usage is Critical!")
          }
      }
    ]...) : pair_key => pair_value
    #----------------------------------------------------------------------#
    # Filter out unwanted alert rules based on conditions:                 #
    # 1. Only some of the servers need backup check                        #
    # 2. DT or S3 servers doesn't have a certificate at all               #
    # 3. No need to check these servers state                              #
    #----------------------------------------------------------------------#
    if !(
      (pair_value.alert_key == "backup" && contains(local.skip_backup_for, pair_value.server.name)) ||
      (pair_value.alert_key == "cert_exp" && contains(local.skip_certs_exp_for, pair_value.server.name)) ||
      (pair_value.alert_key == "state" && contains(local.skip_state_check_for, pair_value.server.name))
    )
  }

  # Queries per OS and alert type, with placeholders 'ip' or 'url' to be replaced dynamically in "model" parameter
  queries = {
    linux = {
      cpu      = "{\"disableTextWrap\":false,\"editorMode\":\"code\",\"expr\":\"(((count(count(node_cpu_seconds_total{instance=\\\"ip\\\"}) by (cpu))) - avg sum by (mode)(irate(node_cpu_seconds_total{instance=\\\"ip\\\",mode=\\\"idle\\\"}[5m]))) / count(count(node_cpu_seconds_total{instance=\\\"ip\\\"}) by (cpu))) * 100\",\"instant\":true,\"intervalMs\":1000,\"legendFormat\":\"__auto\",\"range\":false,\"refId\":\"A\"}"
      memory   = "{\"disableTextWrap\":false,\"editorMode\":\"code\",\"expr\":\"100 - (node_memory_MemAvailable_bytes{instance=\\\"ip\\\"} / node_memory_MemTotal_bytes{instance=\\\"ip\\\"}) * 100\",\"instant\":true,\"intervalMs\":1000,\"legendFormat\":\"__auto\",\"range\":false,\"refId\":\"A\"}"
      storage  = "{\"editorMode\":\"code\",\"expr\":\"100 - (node_filesystem_avail_bytes{instance=\\\"ip\\\", mountpoint=\\\"/\\\"} / node_filesystem_size_bytes{instance=\\\"ip\\\", mountpoint=\\\"/\\\"}) * 100\",\"instant\":true,\"intervalMs\":1000,\"legendFormat\":\"__auto\",\"range\":false,\"refId\":\"A\"}"
      cert_exp = "{\"editorMode\":\"code\",\"expr\":\"(probe_ssl_earliest_cert_expiry{instance=\\\"ip\\\"} - time()) / 3600 / 24\",\"instant\":true,\"intervalMs\":1000,\"legendFormat\":\"__auto\",\"range\":false,\"refId\":\"A\"}"
      backup   = "{\"editorMode\":\"code\",\"expr\":\"backup_success_status{instance=\\\"ip\\\"}\",\"instant\":true,\"intervalMs\":1000,\"legendFormat\":\"__auto\",\"range\":false,\"refId\":\"A\"}"
      state    = "{\"editorMode\":\"code\",\"expr\":\"probe_success{instance=\\\"ip\\\"}\",\"instant\":true,\"intervalMs\":1000,\"legendFormat\":\"__auto\",\"range\":false,\"refId\":\"A\"}"
    }
    windows = {
      cpu      = "{\"editorMode\":\"code\",\"expr\":\"100 - (avg by (instance) (irate(windows_cpu_time_total{mode=\\\"idle\\\", instance=\\\"ip\\\"}[5m]))) * 100\",\"instant\":true,\"intervalMs\":1000,\"legendFormat\":\"__auto\",\"range\":false,\"refId\":\"A\"}"
      memory   = "{\"editorMode\":\"code\",\"expr\":\"100 - (windows_os_physical_memory_free_bytes{instance=\\\"ip\\\"} / windows_cs_physical_memory_bytes{instance=\\\"ip\\\"}) * 100\",\"instant\":true,\"intervalMs\":1000,\"legendFormat\":\"__auto\",\"range\":false,\"refId\":\"A\"}"
      storage  = "{\"disableTextWrap\":false,\"editorMode\":\"code\",\"expr\":\"100 - (windows_logical_disk_free_bytes{instance=\\\"ip\\\",volume=\\\"C:\\\\\\\\\"} / windows_logical_disk_size_bytes{instance=\\\"ip\\\",volume=\\\"C:\\\\\\\\\"}) * 100\",\"instant\":true,\"intervalMs\":1000,\"legendFormat\":\"__auto\",\"range\":false,\"refId\":\"A\"}"
      cert_exp = "{\"editorMode\":\"code\",\"expr\":\"(probe_ssl_earliest_cert_expiry{instance=\\\"ip\\\"} - time()) / 3600 / 24\",\"instant\":true,\"intervalMs\":1000,\"legendFormat\":\"__auto\",\"range\":false,\"refId\":\"A\"}"
      backup   = "{\"editorMode\":\"code\",\"expr\":\"backup_success_status{instance=\\\"ip\\\"}\",\"instant\":true,\"intervalMs\":1000,\"legendFormat\":\"__auto\",\"range\":false,\"refId\":\"A\"}"
      state    = "{\"editorMode\":\"code\",\"expr\":\"probe_success{instance=\\\"ip\\\"}\",\"instant\":true,\"intervalMs\":1000,\"legendFormat\":\"__auto\",\"range\":false,\"refId\":\"A\"}"
    }
  }

  # Generic expressions for ref_id "B" (The second "data" block) to evaluate alert conditions
  exprs = {
    cpu      = "{\"conditions\":[{\"evaluator\":{\"params\":[95,0],\"type\":\"gt\"},\"operator\":{\"type\":\"and\"},\"query\":{\"params\":[\"A\"]},\"reducer\":{\"params\":[],\"type\":\"last\"},\"type\":\"query\"}],\"dataSource\":\"__expr__\",\"expression\":\"A\",\"hide\":false,\"refId\":\"B\",\"type\":\"classic_conditions\"}"
    memory   = "{\"conditions\":[{\"evaluator\":{\"params\":[95,0],\"type\":\"gt\"},\"operator\":{\"type\":\"and\"},\"query\":{\"params\":[\"A\"]},\"reducer\":{\"params\":[],\"type\":\"last\"},\"type\":\"query\"}],\"dataSource\":\"__expr__\",\"expression\":\"A\",\"hide\":false,\"refId\":\"B\",\"type\":\"classic_conditions\"}"
    storage  = "{\"conditions\":[{\"evaluator\":{\"params\":[95,0],\"type\":\"gt\"},\"operator\":{\"type\":\"and\"},\"query\":{\"params\":[\"A\"]},\"reducer\":{\"params\":[],\"type\":\"last\"},\"type\":\"query\"}],\"dataSource\":\"__expr__\",\"expression\":\"A\",\"hide\":false,\"refId\":\"B\",\"type\":\"classic_conditions\"}"
    cert_exp = "{\"conditions\":[{\"evaluator\":{\"params\":[14,0],\"type\":\"lt\"},\"operator\":{\"type\":\"and\"},\"query\":{\"params\":[\"A\"]},\"reducer\":{\"params\":[],\"type\":\"last\"},\"type\":\"query\"}],\"dataSource\":\"__expr__\",\"expression\":\"A\",\"hide\":false,\"refId\":\"B\",\"type\":\"classic_conditions\"}"
    backup   = "{\"conditions\":[{\"evaluator\":{\"params\":[1,0],\"type\":\"lt\"},\"operator\":{\"type\":\"and\"},\"query\":{\"params\":[\"A\"]},\"reducer\":{\"params\":[],\"type\":\"last\"},\"type\":\"query\"}],\"dataSource\":\"__expr__\",\"expression\":\"A\",\"hide\":false,\"refId\":\"B\",\"type\":\"classic_conditions\"}"
    state    = "{\"conditions\":[{\"evaluator\":{\"params\":[1,0],\"type\":\"lt\"},\"operator\":{\"type\":\"and\"},\"query\":{\"params\":[\"A\"]},\"reducer\":{\"params\":[],\"type\":\"last\"},\"type\":\"query\"}],\"dataSource\":\"__expr__\",\"expression\":\"A\",\"hide\":false,\"refId\":\"B\",\"type\":\"classic_conditions\"}"
  }

  # Servers that doesn't require a backup Alert
  skip_backup_for = [
    "Example Server Prod"
  ]

  # Servers that doesn't require a certificates expiration date Alert
  skip_certs_exp_for = [
    "Example Server Test"
  ]

  # Servers that doesn't require state Alert
  skip_state_check_for = [
    "Example Linux Server"
  ]
}
