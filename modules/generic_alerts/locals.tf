# Local values defining reusable maps and filtering logic for alert rules
locals {
  #----------------------------------------------------------------------#
  # Alert type definitions — display name, description, summary,        #
  # and severity for each generic alert. Referenced in main.tf for      #
  # rule naming, annotations, and labels.                               #
  # To add a new alert type: add an entry here, add matching query      #
  # entries in the `queries` map below, and add a threshold in `exprs`. #
  #----------------------------------------------------------------------#
  alert_types = {
    cpu = {
      display_name = "CPU Usage is Critical!"
      description  = "When CPU usage becomes critical it may cause a system failure, it's better to check server's processes, a restart can help."
      summary      = "Server's CPU is at critical level!"
      severity     = "High"
    }
    memory = {
      display_name = "Memory Usage is Critical!"
      description  = "When Memory usage becomes critical it may cause a system failure, it's better to check server's background processes, a restart can help."
      summary      = "Server's Memory percent is at critical level!"
      severity     = "Critical"
    }
    storage = {
      display_name = "Storage is Almost full!"
      description  = "Full storage will mostly affect the repository server, may cause CI/CD pipelines to fail. Clear the trash can or run garbage collection."
      summary      = "Server's Hard Disk is full!"
      severity     = "Critical"
    }
    cert_exp = {
      display_name = "Certificate is almost expired!"
      description  = "When system's certificate is expired, users can't access the system from browser, also may cause pipelines failure. Please update the certificate."
      summary      = "There are less than 14 days left until system's certificate is expired!"
      severity     = "High"
    }
    backup = {
      display_name = "Backup failed!"
      description  = "Backup is one of the most important processes on our systems, first, check the backup network folder then the script, then the cronjob."
      summary      = "The system isn't backing up!"
      severity     = "High"
    }
    state = {
      display_name = "System is Down!"
      description  = "The system is down lol, go do something, you shouldn't read this at all. (Try to restart maybe)"
      summary      = "The system is down, users can't access it"
      severity     = "Critical"
    }
  }

  #----------------------------------------------------------------------#
  # Flatten all alert rules into a map keyed by "serverName|alertKey"   #
  # Each entry holds the server object, alert key, and display name,    #
  # then filters out combinations excluded by per-server skip flags.    #
  #----------------------------------------------------------------------#
  alert_rule_pairs = {
    for pair_key, pair_value in merge([
      for srv in var.servers : {
        for alert_key, alert_obj in local.alert_types :
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
  # Paste the `model` value from Grafana's Terraform export here.       #
  # See README: "How to Get Query and Expression Strings".              #
  #----------------------------------------------------------------------#
  queries = {
    linux = {
      cpu      = "<linux-cpu-query-from-grafana-export>"
      memory   = "<linux-memory-query-from-grafana-export>"
      storage  = "<linux-storage-query-from-grafana-export>"
      cert_exp = "<linux-cert-exp-query-from-grafana-export>"
      backup   = "<linux-backup-query-from-grafana-export>"
      state    = "<linux-state-query-from-grafana-export>"
    }
    windows = {
      cpu      = "<windows-cpu-query-from-grafana-export>"
      memory   = "<windows-memory-query-from-grafana-export>"
      storage  = "<windows-storage-query-from-grafana-export>"
      cert_exp = "<windows-cert-exp-query-from-grafana-export>"
      backup   = "<windows-backup-query-from-grafana-export>"
      state    = "<windows-state-query-from-grafana-export>"
    }
  }

  #----------------------------------------------------------------------#
  # Threshold expressions for ref_id "B" — evaluate the query result.   #
  # Paste the `model` from the second data block of Grafana's export.   #
  # Thresholds: cpu/memory/storage > 95%, cert_exp < 14 days,           #
  # backup/state < 1 (0 = failed/down).                                 #
  #----------------------------------------------------------------------#
  exprs = {
    cpu      = "<cpu-threshold-expr-from-grafana-export>"
    memory   = "<memory-threshold-expr-from-grafana-export>"
    storage  = "<storage-threshold-expr-from-grafana-export>"
    cert_exp = "<cert-exp-threshold-expr-from-grafana-export>"
    backup   = "<backup-threshold-expr-from-grafana-export>"
    state    = "<state-threshold-expr-from-grafana-export>"
  }
}
