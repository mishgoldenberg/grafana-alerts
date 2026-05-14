variable "datasource_uid" {
  description = "The UID of the Prometheus (or other) datasource"
  type        = string
}

variable "systems" {
  type = list(object({
    system_name = string
    os          = string
    servers = list(object({
      name = string
      ip   = string
      url  = string
    }))
  }))
  description = "List of objects containing info about each of our systems"
}

variable "contact_point_name" {
  type        = string
  description = "The one and only contact point to use"
}

variable "specific_alert_types" {
  type = map(map(map(object({
    display_name = string
    description  = string
    summary      = string
    severity     = string
    query        = string
    expr         = string
  }))))
  description = "Specific alert types to create for each monitored system"
}
