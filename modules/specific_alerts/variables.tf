variable "system_name" {
  type        = string
  description = "Name of the monitored system, used to name the alert group"
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
    skip_backup = optional(bool, false)
    skip_cert   = optional(bool, false)
    skip_state  = optional(bool, false)
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

# Keyed by server name (or "__system__" for system-level alerts), then alert key.
# Root main.tf passes only this system's slice of the full specific_alert_types map.
variable "specific_alert_types" {
  type = map(map(object({
    display_name = string
    description  = string
    summary      = string
    severity     = string
    query        = string # JSON string from Grafana Terraform export — use __IP__ as instance placeholder
    expr         = string # JSON string from Grafana Terraform export
  })))
  description = "Specific alerts for this system, keyed by server name then alert key"
}
