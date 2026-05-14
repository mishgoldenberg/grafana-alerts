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
