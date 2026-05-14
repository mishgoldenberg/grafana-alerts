variable "datasource_uid" {
  type        = string
  description = "UID of the Prometheus (or Mimir) datasource in Grafana"
}

variable "folder_uid" {
  type        = string
  description = "UID of the Grafana folder where all alert groups will be created"
}

variable "contact_point_name" {
  type        = string
  description = "Name of the Grafana contact point to route all alerts to"
}

variable "systems" {
  type = list(object({
    system_name = string
    os          = string # "linux" or "windows"
    servers = list(object({
      name        = string
      ip          = string # host:port — used as the Prometheus instance label
      url         = string # full URL — used for cert_exp and state (Blackbox exporter)
      skip_backup = optional(bool, false) # true = no backup alert for this server
      skip_cert   = optional(bool, false) # true = no certificate expiry alert
      skip_state  = optional(bool, false) # true = no uptime/state alert
    }))
  }))
  description = "List of monitored systems, each with an OS type and a list of servers"
}

# Three-level map: system_name -> server_name (or "__system__") -> alert_key -> config.
# Only systems present here get a specific_alerts group created.
variable "specific_alert_types" {
  type = map(map(map(object({
    display_name = string
    description  = string
    summary      = string
    severity     = string
    query        = string # JSON from Grafana Terraform export — use __IP__ as instance placeholder
    expr         = string # JSON from Grafana Terraform export
  }))))
  default     = {}
  description = "System-specific alert definitions, keyed by system -> server -> alert key"
}
