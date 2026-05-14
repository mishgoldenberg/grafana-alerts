# Local values defining reusable maps and filtering logic for alert rules
locals {
  #----------------------------------------------------------------------#
  # Flatten all alert rules into a map keyed by "serverName|alertKey"   #
  # Each entry holds the server object, alert key, and display name,    #
  # then filters out combinations that are skipped per-server flags.    #
  #----------------------------------------------------------------------#
  alert_rule_pairs = {
    for pair_key, pair_value in merge([
      for srv in var.servers : {
        for alert_key, alert_obj in var.alert_types :
          "${srv.name}|${alert_key}" => {
            server     = srv
            alert_key  = alert_key
            alert_name = alert_obj.display_name
          }
      }
    ]...) : pair_key => pair_value
    # Skip alerts based on per-server flags defined in terraform.tfvars
    if !(
      (pair_value.alert_key == "backup"   && pair_value.server.skip_backup) ||
      (pair_value.alert_key == "cert_exp" && pair_value.server.skip_cert) ||
      (pair_value.alert_key == "state"    && pair_value.server.skip_state)
    )
  }

  #----------------------------------------------------------------------#
  # PromQL queries per OS and alert type.                                #
  # __IP__ is a placeholder replaced at apply-time with the real        #
  # server IP (or URL for cert_exp/state) — see main.tf model field.    #
  # These JSON strings are copied from Grafana's Terraform export        #
  # (see README: "How to Get Query and Expression Strings").             #
  #----------------------------------------------------------------------#
  queries = {
    linux = {
      cpu      = "{\"disableTextWrap\":false,\"editorMode\":\"code\",\"expr\":\"(((count(count(node_cpu_seconds_total{instance=\\\"__IP__\\\"}) by (cpu))) - avg sum by (mode)(irate(node_cpu_seconds_total{instance=\\\"__IP__\\\",mode=\\\"idle\\\"}[5m]))) / count(count(node_cpu_seconds_total{instance=\\\"__IP__\\\"}) by (cpu))) * 100\",\"instant\":true,\"intervalMs\":1000,\"legendFormat\":\"__auto\",\"range\":false,\"refId\":\"A\"}"
      memory   = "{\"disableTextWrap\":false,\"editorMode\":\"code\",\"expr\":\"100 - (node_memory_MemAvailable_bytes{instance=\\\"__IP__\\\"} / node_memory_MemTotal_bytes{instance=\\\"__IP__\\\"}) * 100\",\"instant\":true,\"intervalMs\":1000,\"legendFormat\":\"__auto\",\"range\":false,\"refId\":\"A\"}"
      storage  = "{\"editorMode\":\"code\",\"expr\":\"100 - (node_filesystem_avail_bytes{instance=\\\"__IP__\\\", mountpoint=\\\"/\\\"} / node_filesystem_size_bytes{instance=\\\"__IP__\\\", mountpoint=\\\"/\\\"}) * 100\",\"instant\":true,\"intervalMs\":1000,\"legendFormat\":\"__auto\",\"range\":false,\"refId\":\"A\"}"
      cert_exp = "{\"editorMode\":\"code\",\"expr\":\"(probe_ssl_earliest_cert_expiry{instance=\\\"__IP__\\\"} - time()) / 3600 / 24\",\"instant\":true,\"intervalMs\":1000,\"legendFormat\":\"__auto\",\"range\":false,\"refId\":\"A\"}"
      backup   = "{\"editorMode\":\"code\",\"expr\":\"backup_success_status{instance=\\\"__IP__\\\"}\",\"instant\":true,\"intervalMs\":1000,\"legendFormat\":\"__auto\",\"range\":false,\"refId\":\"A\"}"
      state    = "{\"editorMode\":\"code\",\"expr\":\"probe_success{instance=\\\"__IP__\\\"}\",\"instant\":true,\"intervalMs\":1000,\"legendFormat\":\"__auto\",\"range\":false,\"refId\":\"A\"}"
    }
    windows = {
      cpu      = "{\"editorMode\":\"code\",\"expr\":\"100 - (avg by (instance) (irate(windows_cpu_time_total{mode=\\\"idle\\\", instance=\\\"__IP__\\\"}[5m]))) * 100\",\"instant\":true,\"intervalMs\":1000,\"legendFormat\":\"__auto\",\"range\":false,\"refId\":\"A\"}"
      memory   = "{\"editorMode\":\"code\",\"expr\":\"100 - (windows_os_physical_memory_free_bytes{instance=\\\"__IP__\\\"} / windows_cs_physical_memory_bytes{instance=\\\"__IP__\\\"}) * 100\",\"instant\":true,\"intervalMs\":1000,\"legendFormat\":\"__auto\",\"range\":false,\"refId\":\"A\"}"
      storage  = "{\"disableTextWrap\":false,\"editorMode\":\"code\",\"expr\":\"100 - (windows_logical_disk_free_bytes{instance=\\\"__IP__\\\",volume=\\\"C:\\\\\\\\\"} / windows_logical_disk_size_bytes{instance=\\\"__IP__\\\",volume=\\\"C:\\\\\\\\\"}) * 100\",\"instant\":true,\"intervalMs\":1000,\"legendFormat\":\"__auto\",\"range\":false,\"refId\":\"A\"}"
      cert_exp = "{\"editorMode\":\"code\",\"expr\":\"(probe_ssl_earliest_cert_expiry{instance=\\\"__IP__\\\"} - time()) / 3600 / 24\",\"instant\":true,\"intervalMs\":1000,\"legendFormat\":\"__auto\",\"range\":false,\"refId\":\"A\"}"
      backup   = "{\"editorMode\":\"code\",\"expr\":\"backup_success_status{instance=\\\"__IP__\\\"}\",\"instant\":true,\"intervalMs\":1000,\"legendFormat\":\"__auto\",\"range\":false,\"refId\":\"A\"}"
      state    = "{\"editorMode\":\"code\",\"expr\":\"probe_success{instance=\\\"__IP__\\\"}\",\"instant\":true,\"intervalMs\":1000,\"legendFormat\":\"__auto\",\"range\":false,\"refId\":\"A\"}"
    }
  }

  #----------------------------------------------------------------------#
  # Threshold expressions for ref_id "B" — evaluate the query result.   #
  # These are also copied from Grafana's Terraform export.               #
  # Thresholds: cpu/memory/storage > 95%, cert_exp < 14 days,           #
  # backup/state < 1 (i.e. 0 = failed/down).                            #
  #----------------------------------------------------------------------#
  exprs = {
    cpu      = "{\"conditions\":[{\"evaluator\":{\"params\":[95,0],\"type\":\"gt\"},\"operator\":{\"type\":\"and\"},\"query\":{\"params\":[\"A\"]},\"reducer\":{\"params\":[],\"type\":\"last\"},\"type\":\"query\"}],\"dataSource\":\"__expr__\",\"expression\":\"A\",\"hide\":false,\"refId\":\"B\",\"type\":\"classic_conditions\"}"
    memory   = "{\"conditions\":[{\"evaluator\":{\"params\":[95,0],\"type\":\"gt\"},\"operator\":{\"type\":\"and\"},\"query\":{\"params\":[\"A\"]},\"reducer\":{\"params\":[],\"type\":\"last\"},\"type\":\"query\"}],\"dataSource\":\"__expr__\",\"expression\":\"A\",\"hide\":false,\"refId\":\"B\",\"type\":\"classic_conditions\"}"
    storage  = "{\"conditions\":[{\"evaluator\":{\"params\":[95,0],\"type\":\"gt\"},\"operator\":{\"type\":\"and\"},\"query\":{\"params\":[\"A\"]},\"reducer\":{\"params\":[],\"type\":\"last\"},\"type\":\"query\"}],\"dataSource\":\"__expr__\",\"expression\":\"A\",\"hide\":false,\"refId\":\"B\",\"type\":\"classic_conditions\"}"
    cert_exp = "{\"conditions\":[{\"evaluator\":{\"params\":[14,0],\"type\":\"lt\"},\"operator\":{\"type\":\"and\"},\"query\":{\"params\":[\"A\"]},\"reducer\":{\"params\":[],\"type\":\"last\"},\"type\":\"query\"}],\"dataSource\":\"__expr__\",\"expression\":\"A\",\"hide\":false,\"refId\":\"B\",\"type\":\"classic_conditions\"}"
    backup   = "{\"conditions\":[{\"evaluator\":{\"params\":[1,0],\"type\":\"lt\"},\"operator\":{\"type\":\"and\"},\"query\":{\"params\":[\"A\"]},\"reducer\":{\"params\":[],\"type\":\"last\"},\"type\":\"query\"}],\"dataSource\":\"__expr__\",\"expression\":\"A\",\"hide\":false,\"refId\":\"B\",\"type\":\"classic_conditions\"}"
    state    = "{\"conditions\":[{\"evaluator\":{\"params\":[1,0],\"type\":\"lt\"},\"operator\":{\"type\":\"and\"},\"query\":{\"params\":[\"A\"]},\"reducer\":{\"params\":[],\"type\":\"last\"},\"type\":\"query\"}],\"dataSource\":\"__expr__\",\"expression\":\"A\",\"hide\":false,\"refId\":\"B\",\"type\":\"classic_conditions\"}"
  }
}
