########################################################
# Root main.tf                                         #
# Purpose: Define the backend, providers, and call all modules #
########################################################

terraform {
  required_providers {
    grafana = {
      source  = "hashicorp/grafana"
      version = "4.1.0"
    }
  }
  #----------------------------------------------------------------------#
  # Terraform backend configuration                                      #
  # Stores Terraform state in a remote location                          #
  # This example uses an S3-compatible backend                           #
  # Credentials are stored in environmental variables                    #
  #----------------------------------------------------------------------#
  backend "s3" {
    bucket                      = "<terraform-state-bucket>"
    key                         = "terraform.tfstate"
    region                      = "<region>"
    endpoint                    = "<s3-endpoint-url>"
    # access_key = For access key, please set an env variable called: AWS_ACCESS_KEY_ID
    # secret_key = For secret key, please set an env variable called: AWS_SECRET_ACCESS_KEY
    skip_credentials_validation = true
    skip_region_validation      = true
    skip_requesting_account_id  = true
    force_path_style            = true
  }
}

#----------------------------------------------------------------------#
# Provider configuration                                               #
# Authenticates Terraform with Grafana                                 #
# Token is stored in terraform.tfvars                                  #
#----------------------------------------------------------------------#
provider "grafana" {
  # url  = For the url, please set an env variable called: GRAFANA_URL
  # auth = For the token, please set an env variable called: GRAFANA_AUTH
  insecure_skip_verify = true
}

#----------------------------------------------------------------------#
# Module: call: generic alerts                                         #
# Loops through each system and sends it's info to the module          #
# Deploys a set of generic alert rules                                 #
# A group for each monitored system                                    #
#----------------------------------------------------------------------#
module "generic_alerts" {
  for_each = {
    for idx, sys in var.systems :
    idx => sys
    if sys.system_name != "Example System"
  }

  source = "./modules/generic_alerts"

  system_name        = each.value.system_name
  os                 = each.value.os
  servers            = each.value.servers

  datasource_uid     = var.datasource_uid
  contact_point_name = var.contact_point_name
}

#----------------------------------------------------------------------#
# Module: call: "specific" alerts                                      #
# Loops through each system and sends it's info to the module          #
# Deploys a set of "specific" alert rules                              #
# A group for each monitored system                                    #
#----------------------------------------------------------------------#
module "specific_alerts" {
  for_each = {
    for idx, sys in var.systems :
    idx => sys
    if contains(keys(var.specific_alert_types), sys.system_name)
  }

  source = "./modules/specific_alerts"

  system_name        = each.value.system_name
  os                 = each.value.os
  servers            = each.value.servers

  specific_alert_types = var.specific_alert_types
  datasource_uid       = var.datasource_uid
  contact_point_name   = var.contact_point_name
}
