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
