########################################################
# Root main.tf                                         #
# Purpose: Configure backend, provider, and invoke    #
#          generic_alerts and specific_alerts modules  #
#          once per monitored system                   #
########################################################

terraform {
  required_providers {
    grafana = {
      source  = "hashicorp/grafana"
      version = "4.1.0"
    }
  }

  # Terraform state is stored remotely in an S3-compatible object store (e.g. MinIO).
  # Bucket/region/endpoint are set here; credentials come from environment variables:
  #   AWS_ACCESS_KEY_ID     — access key
  #   AWS_SECRET_ACCESS_KEY — secret key
  # The skip_* flags and force_path_style are required for non-AWS S3 backends.
  backend "s3" {
    bucket                      = "<terraform-state-bucket>"
    key                         = "terraform.tfstate"
    region                      = "<region>"
    endpoint                    = "<s3-endpoint-url>"
    skip_credentials_validation = true
    skip_region_validation      = true
    skip_requesting_account_id  = true
    force_path_style            = true
  }
}

# Grafana provider — URL and auth token are passed via environment variables:
#   GRAFANA_URL  — e.g. https://grafana.example.com
#   GRAFANA_AUTH — service account token
# insecure_skip_verify is set for closed/internal networks with self-signed certificates.
provider "grafana" {
  insecure_skip_verify = true
}

#----------------------------------------------------------------------#
# Module: generic_alerts                                               #
# Creates one alert group per system with rules for cpu, memory,      #
# storage, cert_exp, backup, and state — skipping combinations        #
# excluded by per-server skip_* flags.                                 #
# "Example System" is excluded (placeholder entry in tfvars).         #
#----------------------------------------------------------------------#
module "generic_alerts" {
  # Use system_name as the map key so reordering systems in tfvars
  # does not cause Terraform to replace existing resources.
  for_each = {
    for sys in var.systems :
    sys.system_name => sys
    if sys.system_name != "Example System"
  }

  source = "./modules/generic_alerts"

  system_name        = each.value.system_name
  os                 = each.value.os
  servers            = each.value.servers
  folder_uid         = var.folder_uid
  datasource_uid     = var.datasource_uid
  contact_point_name = var.contact_point_name
}

#----------------------------------------------------------------------#
# Module: specific_alerts                                              #
# Creates one alert group per system that has entries in              #
# var.specific_alert_types. Only that system's slice of the map is    #
# passed in, keeping the module interface clean and minimal.           #
#----------------------------------------------------------------------#
module "specific_alerts" {
  for_each = {
    for sys in var.systems :
    sys.system_name => sys
    if contains(keys(var.specific_alert_types), sys.system_name)
  }

  source = "./modules/specific_alerts"

  system_name        = each.value.system_name
  servers            = each.value.servers
  folder_uid         = var.folder_uid
  datasource_uid     = var.datasource_uid
  contact_point_name = var.contact_point_name

  # Pass only this system's alert definitions — not the full map
  specific_alert_types = var.specific_alert_types[each.key]
}
