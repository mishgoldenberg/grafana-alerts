variable "system_name" {
  type        = string
  description = "Name of the monitored system, used to name the alert group"
}

variable "os" {
  type        = string
  description = "Operating system type: 'linux' or 'windows' — selects the correct PromQL queries"
}

variable "folder_uid" {
  type        = string
  description = "UID of the Grafana folder where alert groups will be created"
}

variable "servers" {
  type = list(object({
    name        = string
    ip          = string
    url         = string
    skip_backup = optional(bool, false) # Set true for servers that don't run backups
    skip_cert   = optional(bool, false) # Set true for servers without a TLS certificate
    skip_state  = optional(bool, false) # Set true for servers that don't need uptime monitoring
  }))
  description = "List of servers belonging to this system"
}

variable "datasource_uid" {
  type        = string
  description = "UID of the Prometheus (or Mimir) datasource in Grafana"
}

variable "contact_point_name" {
  type        = string
  description = "Name of the Grafana contact point to route alerts to"
}

variable "alert_types" {
  type = map(object({
    display_name = string
    description  = string
    summary      = string
    severity     = string
  }))

  default = {
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

  description = "Map of alert types that apply to every system generically"
}
