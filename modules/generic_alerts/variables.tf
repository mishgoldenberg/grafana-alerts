variable "system_name" {
  type        = string
  description = "Why would you read this, system name is a system name, You don't need a description for that"
}

variable "os" {
  type        = string
  description = "Type of Operational System our servers have"
}

variable "servers" {
  type = list(object({
    name = string
    ip   = string
    url  = string
  }))
  description = "Each of our systems' servers (Like AT, DT, S3, Test, Prod, and etc)"
}

variable "datasource_uid" {
  type        = string
  description = "The UID of the Prometheus (or other) datasource"
}

variable "contact_point_name" {
  type        = string
  description = "The name of the existing contact point to use in rules"
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

  description = "All of the Generic Alerts types that are the same for each of our systems"
}
